import Foundation
import Combine
import Network
import CoreGraphics
import IOKit.ps

/// Watches real macOS signals and nudges Brick to react with a face + bubble, so he
/// gives the user small ambient cues about what the machine is doing. Everything
/// here uses only system frameworks (Mach host stats, IOKit power sources, Network,
/// CoreGraphics, Dispatch) — no third-party deps, matching the project rule.
///
/// Reactions fire on **threshold crossings** (rising/falling edges), not every tick,
/// so Brick nudges once when something changes rather than nagging continuously.
/// The engine's intensity gate keeps a critical state (on fire) from being stomped
/// by a trivial one.
@MainActor
final class SystemMonitor {
    private unowned let engine: EmotionEngine
    private let settings: Settings

    private var timer: Timer?
    private var memPressure: DispatchSourceMemoryPressure?
    private let netMonitor = NWPathMonitor()
    private let netQueue = DispatchQueue(label: "lilcleo.net")

    // Edge-detection state (so we react on change, not every poll).
    private var prevCPU: host_cpu_load_info?
    private var cpuHotStreak = 0
    private var cpuHot = false
    // RAM pressure decays instead of latching: a warning/critical event keeps it
    // "pressured" only while fresh events keep arriving. We can't poll for recovery —
    // `kern…vm_pressure_level` stays at "warning" for minutes as the compressor drains
    // slowly, so a level poll would pin Brick on fire long after the load is gone.
    private static let memHold: TimeInterval = 30
    private var memPressuredUntil = Date.distantPast
    private var memPressured: Bool { Date() < memPressuredUntil }
    private var lastCPUPct = 0         // last sampled CPU%, for the overload bubble copy
    private var onFire = false         // sustained "running on fire" overload is active
    private var thermalHot = false
    private var batteryLow = false
    private var diskLow = false
    private var netDown = false
    private var idleDeep = false
    private var lateNightDay = -1     // day-of-year we last did the late-night nudge

    init(engine: EmotionEngine, settings: Settings) {
        self.engine = engine
        self.settings = settings
    }

    // MARK: Lifecycle

    func start() {
        stop()
        // Network: event-driven, reacts on connectivity flips.
        netMonitor.pathUpdateHandler = { [weak self] path in
            let down = (path.status != .satisfied)
            Task { @MainActor in self?.handleNetwork(down: down) }
        }
        netMonitor.start(queue: netQueue)

        // Memory pressure: kernel tells us; no polling needed. We also listen for
        // `.normal` so we know when RAM has recovered and the fire can go out.
        let src = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical, .normal], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let ev = src.mask
            Task { @MainActor in self.handleMemory(ev) }
        }
        src.resume()
        memPressure = src

        // Everything else: a gentle 4 s poll.
        let t = Timer(timeInterval: 4.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()   // prime immediately
    }

    func stop() {
        timer?.invalidate(); timer = nil
        memPressure?.cancel(); memPressure = nil
        netMonitor.cancel()
    }

    // MARK: Poll

    private func poll() {
        guard settings.reactToSystem else { return }
        checkCPU()
        checkThermal()
        checkBattery()
        checkDisk()
        checkIdle()
        checkTime()
    }

    // MARK: CPU — sustained high load reads as "working hard / heating up"

    private func checkCPU() {
        guard let usage = cpuUsage() else { return }
        lastCPUPct = Int((usage * 100).rounded())
        if usage > 0.88 { cpuHotStreak += 1 } else { cpuHotStreak = 0 }
        cpuHot = cpuHotStreak >= 2      // ~8 s sustained before we say anything
        evaluateOverload()
    }

    // MARK: Overload — CPU and/or RAM pegged: run on fire until *both* recover

    /// Single source of truth for the "running on fire" state, fed by both the CPU
    /// poll and the (event-driven) memory-pressure handler. Brick ignites on the
    /// rising edge, keeps panicking while either signal is hot, and only calms down
    /// once CPU **and** RAM have both recovered.
    private func evaluateOverload() {
        guard settings.reactToSystem else { return }
        let overloaded = cpuHot || memPressured
        if overloaded {
            let msg = overloadMessage()
            if !onFire {
                onFire = true
                engine.beginEmergency(message: msg)
            } else {
                engine.sustainEmergency(message: msg)   // keep it alive between polls
            }
        } else if onFire {
            onFire = false
            engine.endEmergency(message: "phew — back to normal 😮‍💨")
        }
    }

    /// Bubble copy describing *what* is on fire (CPU, RAM, or both).
    private func overloadMessage() -> String {
        switch (cpuHot, memPressured) {
        case (true, true):  return "CPU \(lastCPUPct)% & RAM maxed — 🔥🔥"
        case (true, false): return "CPU's slammed — \(lastCPUPct)% 🔥"
        default:            return "memory's maxed out — 🔥"
        }
    }

    private func cpuUsage() -> Double? {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        defer { prevCPU = info }
        guard let prev = prevCPU else { return nil }
        let user = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let sys  = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + sys + idle + nice
        guard total > 0 else { return nil }
        return (user + sys + nice) / total
    }

    // MARK: Thermal — serious/critical = literally on fire

    private func checkThermal() {
        let state = ProcessInfo.processInfo.thermalState
        let hot = (state == .serious || state == .critical)
        if hot && !thermalHot {
            let level = (state == .critical) ? "critical" : "serious"
            engine.react(.error, message: "overheating — thermal is \(level)! 🔥")
        } else if !hot && thermalHot {
            engine.trigger(emotion: .relieved, message: "phew, cooled off 😮‍💨", hold: 2.0, intensity: .info)
        }
        thermalHot = hot
    }

    // MARK: Battery

    private func checkBattery() {
        guard let (pct, charging) = batteryState() else { return }   // no battery → skip
        let low = (pct <= 15 && !charging)
        if low && !batteryLow {
            engine.trigger(emotion: .tired, action: .yawn,
                           message: "battery low — \(pct)% 🔋", hold: 3.5, intensity: .alert)
        } else if !low && batteryLow && charging {
            engine.trigger(emotion: .relieved, action: .coffee,
                           message: "ah, plugged in ⚡️", hold: 2.5, intensity: .info)
        }
        batteryLow = low
    }

    private func batteryState() -> (pct: Int, charging: Bool)? {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for src in list {
            guard let desc = IOPSGetPowerSourceDescription(snap, src)?.takeUnretainedValue() as? [String: Any],
                  let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let state = desc[kIOPSPowerSourceStateKey] as? String
            let charging = (state == kIOPSACPowerValue) || (desc[kIOPSIsChargingKey] as? Bool ?? false)
            return (Int((Double(cur) / Double(max)) * 100.0), charging)
        }
        return nil
    }

    // MARK: Disk

    private func checkDisk() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let vals = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = vals.volumeAvailableCapacityForImportantUsage else { return }
        let gb = Double(bytes) / 1_000_000_000.0
        let low = gb < 5
        if low && !diskLow {
            engine.trigger(emotion: .nervous, action: .raincloud,
                           message: "low on disk — \(String(format: "%.1f", gb)) GB left 💾",
                           hold: 3.0, intensity: .alert)
        }
        diskLow = low
    }

    // MARK: Memory pressure (event-driven)

    private func handleMemory(_ ev: DispatchSource.MemoryPressureEvent) {
        guard settings.reactToSystem else { return }
        // A warning/critical event refreshes the pressure window so it joins CPU in the
        // overload decision; it then decays on its own if no fresh events arrive (load
        // gone). A `.normal` event, when it does come, clears it immediately.
        if ev.contains(.warning) || ev.contains(.critical) {
            memPressuredUntil = Date().addingTimeInterval(Self.memHold)
        } else if ev.contains(.normal) {
            memPressuredUntil = .distantPast
        }
        evaluateOverload()
    }

    // MARK: Network (event-driven)

    private func handleNetwork(down: Bool) {
        guard settings.reactToSystem else { netDown = down; return }
        if down && !netDown {
            engine.trigger(emotion: .confused, action: .shrug,
                           message: "I'm offline 📡", hold: 3.0, intensity: .alert)
        } else if !down && netDown {
            engine.trigger(emotion: .relieved, message: "back online 🛜", hold: 2.0, intensity: .info)
        }
        netDown = down
    }

    // MARK: Idle — wave to get attention when the user's been gone a while

    private func checkIdle() {
        let any = CGEventType(rawValue: ~0)!     // kCGAnyInputEventType
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: any)
        let deep = idle > 240    // 4 min away from keyboard/mouse
        if deep && !idleDeep {
            engine.trigger(emotion: .curious, action: .wave,
                           message: "still there? 👋", hold: 2.4, intensity: .info)
        }
        idleDeep = deep          // re-arms when the user comes back (idle resets)
    }

    // MARK: Time of day — a gentle late-night "go rest" nudge, once per night

    private func checkTime() {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let day = cal.ordinality(of: .day, in: .era, for: now) ?? 0
        let lateNight = (hour >= 23 || hour < 5)
        if lateNight && lateNightDay != day {
            lateNightDay = day   // once per calendar day; re-arms automatically tomorrow
            engine.trigger(emotion: .tired, action: .coffee,
                           message: "it's late — maybe rest? 😴", hold: 3.5, intensity: .info)
        }
    }
}

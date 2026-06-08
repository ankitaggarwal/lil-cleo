import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// A contact sheet of Cleo's vector character in every action + emotion, used for
/// headless visual review. Run `CLEO_RENDER=/tmp/cleo.png swift run LilCleo` to
/// rasterize it via ImageRenderer (no live screen needed) and exit.
struct GalleryView: View {
    struct Cell: Identifiable { let id = UUID(); let label: String; let emotion: Emotion; let action: Action; let phase: CGFloat }

    private var actionCells: [Cell] {
        [
            .init(label: "idle", emotion: .idle, action: .idle, phase: 0.25),
            .init(label: "walk", emotion: .idle, action: .walk, phase: 0.12),
            .init(label: "run", emotion: .excited, action: .run, phase: 0.12),
            .init(label: "jump", emotion: .happy, action: .jump, phase: 0.42),
            .init(label: "sit", emotion: .idle, action: .sit, phase: 0.0),
            .init(label: "wave", emotion: .happy, action: .wave, phase: 0.5),
            .init(label: "cheer", emotion: .excited, action: .cheer, phase: 0.25),
            .init(label: "panic", emotion: .sad, action: .panic, phase: 0.3),
            .init(label: "think", emotion: .thinking, action: .think, phase: 0.0),
            .init(label: "point", emotion: .curious, action: .point, phase: 0.0),
            .init(label: "shake", emotion: .sad, action: .shake, phase: 0.25),
            .init(label: "celebrate", emotion: .excited, action: .celebrate, phase: 0.12),
            .init(label: "sleep", emotion: .sleeping, action: .sleep, phase: 0.0),
        ]
    }

    private var emotionCells: [Cell] {
        Emotion.allCases.map { .init(label: $0.rawValue, emotion: $0, action: .idle, phase: 0.25) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleo — Actions").font(.system(size: 18, weight: .bold, design: .rounded))
            grid(actionCells)
            Text("Cleo — Emotions (idle pose)").font(.system(size: 18, weight: .bold, design: .rounded))
            grid(emotionCells)
        }
        .padding(20)
        .background(Color(red: 0.93, green: 0.93, blue: 0.95))
    }

    private func grid(_ cells: [Cell]) -> some View {
        let cols = 4
        let rows = stride(from: 0, to: cells.count, by: cols).map { Array(cells[$0..<min($0 + cols, cells.count)]) }
        return VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(rows[r]) { cell in
                        VStack(spacing: 2) {
                            CharacterBody(emotion: cell.emotion, action: cell.action,
                                          phase: cell.phase)
                                .frame(width: 140, height: 170)
                            Text(cell.label).font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                    }
                    ForEach(0..<(cols - rows[r].count), id: \.self) { _ in
                        Color.clear.frame(width: 152, height: 198)
                    }
                }
            }
        }
    }
}

/// A horizontal film strip of one action sampled across its cycle — lets us
/// verify motion (e.g. a walk cycle) in a single still.
struct StripView: View {
    var action: Action
    var emotion: Emotion = .idle
    var frames: Int = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(action.label) cycle").font(.system(size: 16, weight: .bold, design: .rounded))
            HStack(spacing: 6) {
                ForEach(0..<frames, id: \.self) { i in
                    CharacterBody(emotion: emotion, action: action,
                                  phase: CGFloat(i) / CGFloat(frames))
                        .frame(width: 120, height: 165)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white))
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.93, green: 0.93, blue: 0.95))
    }
}

enum GalleryRenderer {
    @MainActor static func renderStrip(_ action: Action, emotion: Emotion = .idle, to path: String) -> Bool {
        let renderer = ImageRenderer(content: StripView(action: action, emotion: emotion))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return false }
        do { try png.write(to: URL(fileURLWithPath: path)); return true } catch { return false }
    }

    /// Render the bundled side-walk SPRITES for a character into an animated GIF,
    /// using the exact frame-selection + bob the live `ImageCharacterView` uses and
    /// the same `Bundle.module` loader. This verifies a sprite character (e.g.
    /// "brick") is correctly bundled and its walk cycles/loops in-app.
    ///   CLEO_SPRITE_GIF=/tmp/brick-walk.gif CLEO_CHARACTER=brick swift run LilCleo
    @MainActor static func renderSpriteWalkGIF(character: String, to path: String,
                                               cycles: Int = 2, fps: Double = 12) -> Bool {
        let n = ImageCharacterView.walkFrameCount(character)
        guard ImageCharacterView.sprite(character, "walk1") != nil else { return false }
        let url = URL(fileURLWithPath: path)
        let total = n * cycles
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, total, nil) else { return false }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFDelayTime: 1.0 / fps]] as CFDictionary
        for step in 0..<total {
            let k = step % n + 1
            // match ImageCharacterView's walk bob (linked to its walkFPS)
            let t = Double(step) / fps
            let bob = CGFloat(abs(sin(t * .pi * 6.5 / 2))) * 2.5
            let cell = ZStack {
                if let img = ImageCharacterView.sprite(character, "walk\(k)") {
                    Image(nsImage: img).resizable().interpolation(.high).scaledToFit()
                }
            }
            .frame(width: 138, height: 184, alignment: .bottom)
            .offset(y: -bob)
            .frame(width: 150, height: 192, alignment: .bottom)
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
            let r = ImageRenderer(content: cell)
            r.scale = 2
            guard let cg = r.cgImage else { return false }
            CGImageDestinationAddImage(dest, cg, frameProps)
        }
        return CGImageDestinationFinalize(dest)
    }

    /// A frame in an animated sequence: an action + mood held for `frames` steps.
    struct Beat { let action: Action; let emotion: Emotion; let frames: Int }

    /// Render an animated GIF of a sequence of beats. One-shot actions play 0→1
    /// across their beat; loops cycle. Default light card background.
    @MainActor static func renderGIF(_ beats: [Beat], to path: String,
                                     fps: Double = 24) -> Bool {
        let url = URL(fileURLWithPath: path)
        let total = beats.reduce(0) { $0 + $1.frames }
        guard total > 0,
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, total, nil)
        else { return false }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFDelayTime: 1.0 / fps]] as CFDictionary

        for beat in beats {
            for i in 0..<beat.frames {
                let raw = Double(i) / Double(beat.frames)
                let phase = CGFloat(beat.action.isLocomotion || beat.action.oscillates ? raw : min(raw, 1))
                let cell = CharacterBody(emotion: beat.emotion, action: beat.action,
                                         phase: phase)
                    .frame(width: 150, height: 190)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                let r = ImageRenderer(content: cell)
                r.scale = 2
                guard let cg = r.cgImage else { return false }
                CGImageDestinationAddImage(dest, cg, frameProps)
            }
        }
        return CGImageDestinationFinalize(dest)
    }

    /// Rasterize the gallery to a PNG at `path`. Returns true on success.
    @MainActor static func render(to path: String) -> Bool {
        let renderer = ImageRenderer(content: GalleryView())
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        do { try png.write(to: URL(fileURLWithPath: path)); return true }
        catch { return false }
    }
}

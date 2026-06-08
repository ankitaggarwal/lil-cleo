import SwiftUI

// MARK: - Geometry

/// Tiny 2D vector helper for forward-kinematics joint math.
struct V2 {
    var x: CGFloat, y: CGFloat
    static func + (a: V2, b: V2) -> V2 { V2(x: a.x + b.x, y: a.y + b.y) }
    var cg: CGPoint { CGPoint(x: x, y: y) }
}

private func rad(_ deg: CGFloat) -> CGFloat { deg * .pi / 180 }

/// Joint at `base`, a limb of `len` pointing at `angle` (degrees; 0 = straight
/// down, positive = clockwise). Returns the far end.
private func joint(_ base: V2, _ angle: CGFloat, _ len: CGFloat) -> V2 {
    V2(x: base.x + len * sin(rad(angle)), y: base.y + len * cos(rad(angle)))
}

// MARK: - Pose

/// A full-body pose: every joint angle (degrees) plus whole-body transforms.
/// Neutral = standing at ease. Each `Action` produces one of these per frame.
struct Pose {
    // Legs (thigh angle from vertical, knee = shin angle relative to thigh)
    var hipL: CGFloat = -4,  hipR: CGFloat = 4
    var kneeL: CGFloat = 5,  kneeR: CGFloat = 5
    // Arms (shoulder = upper-arm angle, elbow = forearm relative to upper)
    var shoulderL: CGFloat = -13, shoulderR: CGFloat = 13
    var elbowL: CGFloat = -12,    elbowR: CGFloat = 12
    // Whole-body
    var bodyDX: CGFloat = 0, bodyDY: CGFloat = 0
    var lean: CGFloat = 0          // degrees, rotates about the feet
    var squash: CGFloat = 1        // y-scale about the feet (squash & stretch)
    var headTilt: CGFloat = 0      // extra head tilt on top of the mood's tilt

    static func lerp(_ a: Pose, _ b: Pose, _ t: CGFloat) -> Pose {
        func l(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        var p = Pose()
        p.hipL = l(a.hipL, b.hipL); p.hipR = l(a.hipR, b.hipR)
        p.kneeL = l(a.kneeL, b.kneeL); p.kneeR = l(a.kneeR, b.kneeR)
        p.shoulderL = l(a.shoulderL, b.shoulderL); p.shoulderR = l(a.shoulderR, b.shoulderR)
        p.elbowL = l(a.elbowL, b.elbowL); p.elbowR = l(a.elbowR, b.elbowR)
        p.bodyDX = l(a.bodyDX, b.bodyDX); p.bodyDY = l(a.bodyDY, b.bodyDY)
        p.lean = l(a.lean, b.lean); p.squash = l(a.squash, b.squash)
        p.headTilt = l(a.headTilt, b.headTilt)
        return p
    }
}

// MARK: - Action → Pose

extension Action {
    /// The pose for this action at a given cycle phase (0…1).
    func pose(phase: CGFloat) -> Pose {
        let twoPi = CGFloat.pi * 2
        switch self {
        case .idle:
            var p = Pose()
            let breathe = sin(phase * twoPi)
            p.squash = 1 - 0.035 * breathe
            p.bodyDY = 2.4 * breathe
            p.shoulderL = -11 + 2 * breathe; p.shoulderR = 11 - 2 * breathe
            p.hipL = -3 + 1.5 * breathe; p.hipR = 3 - 1.5 * breathe
            return p

        case .walk:
            let c = sin(phase * twoPi)
            var p = Pose()
            p.hipL = -5 + 30 * c;  p.hipR = 5 - 30 * c
            p.kneeL = 6 + 34 * max(0, -c); p.kneeR = 6 + 34 * max(0, c)
            p.shoulderL = -14 - 24 * c; p.shoulderR = 14 + 24 * c
            p.elbowL = -20; p.elbowR = 20
            p.bodyDY = -3.5 * abs(c)
            p.lean = 3
            p.headTilt = 1.2 * sin(phase * twoPi)
            return p

        case .run:
            let c = sin(phase * twoPi)
            var p = Pose()
            p.hipL = -12 + 54 * c;  p.hipR = 12 - 54 * c
            p.kneeL = 16 + 60 * max(0, -c); p.kneeR = 16 + 60 * max(0, c)
            // hard-pumping bent arms read as speed
            p.shoulderL = -52 - 36 * c; p.shoulderR = 52 + 36 * c
            p.elbowL = -112; p.elbowR = 112
            p.bodyDY = -7 * abs(c) - 3
            p.bodyDX = 1.5 * sin(phase * twoPi)
            p.lean = 24
            return p

        case .jump:
            return Action.jumpPose(phase: phase)

        case .sit:
            var p = Pose()
            p.bodyDY = 30; p.squash = 0.95
            p.hipL = -78; p.hipR = 78          // thighs splay out to the sides
            p.kneeL = 74; p.kneeR = -74        // shins fold back down to the ground
            p.shoulderL = -22; p.shoulderR = 22
            p.elbowL = -26; p.elbowR = 26
            return p

        case .wave:
            var p = Pose()
            p.shoulderR = 150
            p.elbowR = -28 + 26 * sin(phase * twoPi)   // forearm waves
            p.shoulderL = -13; p.elbowL = -12
            p.lean = 3
            return p

        case .cheer:
            var p = Pose()
            let hop = abs(sin(phase * twoPi))
            p.shoulderL = -158; p.shoulderR = 158
            p.elbowL = 0; p.elbowR = 0
            p.bodyDY = -7 * hop
            p.hipL = -10; p.hipR = 10
            p.kneeL = 4; p.kneeR = 4
            return p

        case .panic:
            var p = Pose()
            let f = sin(phase * twoPi)
            // hands thrown up beside the head, elbows bent — frantic, NOT a clean
            // victory V (that's cheer). Plus a fast body jitter.
            p.shoulderL = -128 + 22 * f; p.shoulderR = 128 + 22 * f
            p.elbowL = -58; p.elbowR = 58
            p.bodyDX = 3.6 * sin(phase * twoPi * 3)
            p.bodyDY = -4 * abs(f)
            p.hipL = -8 + 14 * f; p.hipR = 8 + 14 * f
            p.kneeL = 4 + 8 * abs(f); p.kneeR = 4 + 8 * abs(f)
            p.headTilt = 4 * f
            return p

        case .think:
            var p = Pose()
            // Hand-to-chin on the LEFT arm (the front-drawn one, so it's visible),
            // IK-solved so the hand lands on the chin (~66,94).
            p.shoulderL = 19; p.elbowL = 60
            p.headTilt = -7
            p.lean = -2
            p.bodyDY = -1
            return p

        case .point:
            var p = Pose()
            p.shoulderR = 82; p.elbowR = -6             // arm extended out & level
            p.shoulderL = -12; p.elbowL = -10
            p.lean = 4
            return p

        case .shake:
            var p = Pose()
            let f = sin(phase * twoPi * 2)               // fast shimmy
            p.bodyDX = 4 * f
            p.headTilt = 9 * f
            p.shoulderL = -20; p.shoulderR = 20
            p.elbowL = -36; p.elbowR = 36                // arms tense at sides
            p.lean = 2 * f
            return p

        case .celebrate:
            var p = Pose()
            let hop = abs(sin(phase * twoPi * 2))        // two hops per cycle
            p.shoulderL = -158 + 14 * sin(phase * twoPi * 4)
            p.shoulderR = 158 - 14 * sin(phase * twoPi * 4)
            p.elbowL = -6; p.elbowR = 6
            p.bodyDY = -15 * hop
            p.hipL = -12; p.hipR = 12
            p.kneeL = 4 + 18 * (1 - hop); p.kneeR = 4 + 18 * (1 - hop)
            return p

        case .sleep:
            var p = Pose()                               // seated, slumped
            p.bodyDY = 26; p.squash = 0.97
            p.hipL = -64; p.hipR = 64
            p.kneeL = 58; p.kneeR = -58
            p.shoulderL = -22; p.shoulderR = 22
            p.elbowL = -30; p.elbowR = 30
            p.headTilt = 12
            p.bodyDY += 1.2 * sin(phase * twoPi)         // slow breathing
            return p

        // The expanded sprite-era actions don't all have bespoke vector poses (the
        // vector puppet is only the no-sprite fallback). Route each NEW action to
        // the nearest existing pose so the fallback still reads and animates.
        case .fistpump, .party, .trophy, .dance:
            return Action.celebrate.pose(phase: phase)
        case .headshake, .glitch:
            return Action.shake.pose(phase: phase)
        case .onFire, .sweating:
            return Action.panic.pose(phase: phase)
        case .salute, .peace, .clap, .nod:
            return Action.wave.pose(phase: phase)
        case .thumbsup, .idea, .coffee, .debug, .fixing, .clipboard:
            return Action.point.pose(phase: phase)
        case .reading, .coding, .loading, .headphones, .raincloud:
            return Action.think.pose(phase: phase)
        case .yawn, .meditate:
            return Action.sit.pose(phase: phase)
        case .bow, .facepalm, .shrug:
            var p = Pose()
            p.lean = self == .bow ? 22 : 0
            p.shoulderL = -40; p.shoulderR = 40; p.elbowL = -30; p.elbowR = 30
            p.headTilt = 8
            return p
        }
    }

    /// Anticipate → launch → apex → land, keyed by phase.
    private static func jumpPose(phase t: CGFloat) -> Pose {
        let stand = Pose()
        var squat = Pose()
        squat.bodyDY = 16; squat.squash = 0.82
        squat.hipL = -16; squat.hipR = 16; squat.kneeL = 44; squat.kneeR = -44
        squat.shoulderL = 8; squat.shoulderR = -8; squat.elbowL = -6; squat.elbowR = 6
        var air = Pose()
        air.bodyDY = -42; air.squash = 1.14
        air.hipL = -14; air.hipR = 14; air.kneeL = 36; air.kneeR = -36  // knees tucked up
        air.shoulderL = -150; air.shoulderR = 150; air.elbowL = -4; air.elbowR = 4

        if t < 0.18 { return Pose.lerp(stand, squat, t / 0.18) }
        if t < 0.42 { return Pose.lerp(squat, air, (t - 0.18) / 0.24) }
        if t < 0.72 { return air }                                   // hang time
        if t < 0.88 { return Pose.lerp(air, squat, (t - 0.72) / 0.16) }
        return Pose.lerp(squat, stand, (t - 0.88) / 0.12)
    }
}

// MARK: - Outfit palette

/// Flat-illustration palette for Cleo's clothed-humanoid look (modeled on the
/// reference: bowler hat, open utility jacket over a tee, loose pants, sneakers).
struct Outfit {
    var skin      = Color(red: 0.96, green: 0.64, blue: 0.74)
    var skinShade = Color(red: 0.89, green: 0.55, blue: 0.66)
    var ink       = Color(red: 0.13, green: 0.11, blue: 0.13)
    var hat       = Color(red: 0.12, green: 0.12, blue: 0.14)
    var jacket    = Color(red: 0.56, green: 0.73, blue: 0.50)
    var jacketDark = Color(red: 0.46, green: 0.63, blue: 0.41)
    var tee       = Color(red: 0.96, green: 0.94, blue: 0.88)
    var pants     = Color(red: 0.94, green: 0.92, blue: 0.84)
    var pantsShade = Color(red: 0.86, green: 0.83, blue: 0.74)
    var shoe      = Color(red: 0.12, green: 0.12, blue: 0.16)
    var sole      = Color(red: 0.93, green: 0.82, blue: 0.42)
}

// MARK: - Renderer

/// Draws Cleo as a posed, clothed humanoid: small head + bowler hat, an open
/// utility jacket over a tee, loose pants, and sneakers, on a two-segment-limb
/// skeletal rig. Pure function of its inputs, so it renders identically live
/// (TimelineView feeds `phase`) or headlessly (ImageRenderer feeds a fixed `phase`).
struct CharacterBody: View {
    let emotion: Emotion
    let action: Action
    let phase: CGFloat
    var blink: Bool = false
    private let o = Outfit()

    // Canvas + skeleton anchors (points), tuned for a ~150pt-tall figure.
    private let W: CGFloat = 140, H: CGFloat = 180
    private var head: V2 { V2(x: 70, y: 42) }
    private let headR: CGFloat = 15
    private var shoulderL: V2 { V2(x: 51, y: 67) }
    private var shoulderR: V2 { V2(x: 89, y: 67) }
    private var hipL: V2 { V2(x: 61, y: 116) }
    private var hipR: V2 { V2(x: 79, y: 116) }
    private let thigh: CGFloat = 28, shin: CGFloat = 24
    private let upperArm: CGFloat = 23, foreArm: CGFloat = 20

    private var effectiveAction: Action {
        if action != .idle { return action }
        switch emotion {
        case .sleeping: return .sleep
        case .thinking: return .think
        default: return .idle
        }
    }

    var body: some View {
        let p = effectiveAction.pose(phase: phase)

        ZStack {
            // Back limbs (right side), slightly shaded for depth.
            leg(hipR, p.hipR, p.kneeR, back: true)
            arm(shoulderR, p.shoulderR, p.elbowR, back: true)

            torso()
            headAndHat(p)
            face(p)

            // Front limbs (left side).
            leg(hipL, p.hipL, p.kneeL, back: false)
            arm(shoulderL, p.shoulderL, p.elbowL, back: false)
        }
        .compositingGroup()
        .scaleEffect(x: 1, y: p.squash, anchor: .bottom)
        .rotationEffect(.degrees(p.lean), anchor: .bottom)
        .offset(x: p.bodyDX, y: p.bodyDY)
        .frame(width: W, height: H)
        .background(alignment: .bottom) { groundShadow(p) }
    }

    // MARK: Torso (open jacket over a tee)

    private func torso() -> some View {
        ZStack {
            // Tee underneath
            TorsoShape(topW: 0.86, botW: 0.62)
                .fill(o.tee)
                .frame(width: 46, height: 58)
                .position(x: 70, y: 91)
            // Jacket: full torso, then a tee "gap" carved down the open front
            TorsoShape(topW: 0.92, botW: 0.66)
                .fill(o.jacket)
                .overlay(
                    // open-front opening showing the tee
                    TorsoShape(topW: 0.22, botW: 0.30)
                        .fill(o.tee)
                        .frame(width: 46, height: 50)
                        .offset(y: 4)
                )
                .frame(width: 50, height: 56)
                .position(x: 70, y: 90)
            // collar lapels
            Triangle().fill(o.jacketDark).frame(width: 11, height: 13)
                .rotationEffect(.degrees(18)).position(x: 63, y: 70)
            Triangle().fill(o.jacketDark).frame(width: 11, height: 13)
                .rotationEffect(.degrees(-18)).scaleEffect(x: -1, y: 1).position(x: 77, y: 70)
            // chest pockets
            pocket().position(x: 60, y: 96)
            pocket().position(x: 80, y: 96)
        }
    }

    private func pocket() -> some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(o.jacketDark, lineWidth: 1.4)
            .frame(width: 11, height: 12)
            .overlay(Rectangle().fill(o.jacketDark).frame(width: 11, height: 1.6).offset(y: -5))
    }

    // MARK: Head + hat

    private func headAndHat(_ p: Pose) -> some View {
        ZStack {
            // neck
            Capsule().fill(o.skinShade).frame(width: 11, height: 12).position(x: 70, y: 60)
            // head
            Circle().fill(o.skin).frame(width: headR * 2, height: headR * 2).position(head.cg)
            // soft brim shadow across the brow
            Ellipse().fill(o.skinShade.opacity(0.28)).frame(width: 24, height: 6)
                .blur(radius: 1).position(x: head.x, y: head.y - 5)
            // bowler hat: rounded dome + brim
            Ellipse().fill(o.hat).frame(width: 27, height: 24).position(x: head.x, y: head.y - 12)
            Ellipse().fill(o.hat).frame(width: 44, height: 9).position(x: head.x, y: head.y - 8)
        }
        .rotationEffect(.degrees(emotion.tilt + p.headTilt), anchor: .init(x: 0.5, y: 0.66))
    }

    // MARK: Limbs

    private func arm(_ base: V2, _ a1: CGFloat, _ a2: CGFloat, back: Bool) -> some View {
        let elbow = joint(base, a1, upperArm)
        let hand = joint(elbow, a1 + a2, foreArm)
        let sleeve = back ? o.jacketDark : o.jacket
        let skin = back ? o.skinShade : o.skin
        return ZStack {
            segment(base, elbow, width: 10, color: sleeve)         // jacket sleeve
            Capsule().fill(sleeve).frame(width: 11, height: 7).position(elbow.cg) // cuff
            segment(elbow, hand, width: 7.5, color: skin)          // bare forearm
            Circle().fill(skin).frame(width: 9, height: 9).position(hand.cg)      // hand
        }
    }

    private func leg(_ base: V2, _ a1: CGFloat, _ a2: CGFloat, back: Bool) -> some View {
        let knee = joint(base, a1, thigh)
        let ankle = joint(knee, a1 + a2, shin)
        let cloth = back ? o.pantsShade : o.pants
        return ZStack {
            segment(base, knee, width: 14, color: cloth)         // baggy pants
            segment(knee, ankle, width: 13, color: cloth)
            Circle().fill(cloth).frame(width: 13, height: 13).position(knee.cg)   // knee
            sneaker(at: ankle, back: back)
        }
    }

    private func sneaker(at p: V2, back: Bool) -> some View {
        let shoe = back ? o.shoe.opacity(0.85) : o.shoe
        return ZStack {
            Ellipse().fill(o.sole).frame(width: 19, height: 7).position(x: p.x + 3, y: p.y + 4)
            Ellipse().fill(shoe).frame(width: 19, height: 11).position(x: p.x + 3, y: p.y)
            Ellipse().fill(.white.opacity(0.15)).frame(width: 6, height: 4).position(x: p.x - 1, y: p.y - 2)
        }
    }

    private func segment(_ a: V2, _ b: V2, width: CGFloat, color: Color) -> some View {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx)
        return Capsule().fill(color)
            .frame(width: len, height: width)
            .rotationEffect(.radians(angle))
            .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    // MARK: Face (small, serene; reads under the hat brim)

    private func face(_ p: Pose) -> some View {
        let eyeY = head.y + 1 + emotion.gaze.height
        let eyeDX: CGFloat = 6
        let gx = emotion.gaze.width
        return ZStack {
            eye().position(x: head.x - eyeDX + gx, y: eyeY)
            eye(brow: emotion == .curious).position(x: head.x + eyeDX + gx, y: eyeY)

            if emotion.blush > 0.34 {
                Circle().fill(Color(red: 0.95, green: 0.45, blue: 0.55).opacity(emotion.blush * 0.7))
                    .frame(width: 7, height: 7).blur(radius: 1).position(x: head.x - 9, y: head.y + 5)
                Circle().fill(Color(red: 0.95, green: 0.45, blue: 0.55).opacity(emotion.blush * 0.7))
                    .frame(width: 7, height: 7).blur(radius: 1).position(x: head.x + 9, y: head.y + 5)
            }

            MouthShape(curve: emotion.mouthCurve, open: emotion.mouthOpen)
                .stroke(o.ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 8)
                .position(x: head.x, y: head.y + 8)
        }
        .rotationEffect(.degrees(emotion.tilt + p.headTilt), anchor: .init(x: 0.5, y: 0.0))
    }

    /// Small eyes. Serene "closed" curve when content; open dot otherwise.
    private func eye(brow: Bool = false) -> some View {
        let serene = (emotion == .happy || emotion == .excited || emotion == .idle || emotion == .sleeping)
        let openness = max(0.06, emotion.eyeOpenness)
        return ZStack {
            if brow {
                Capsule().fill(o.ink).frame(width: 6, height: 1.6).offset(y: -6)
            }
            if (serene && !blink) || (emotion == .sleeping) {
                EyeCrescent().stroke(o.ink, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .frame(width: 8, height: 4)
            } else {
                Capsule().fill(o.ink).frame(width: 4.5, height: blink ? 1.6 : 7 * openness)
            }
        }
        .frame(width: 9, height: 9)
    }

    private func groundShadow(_ p: Pose) -> some View {
        Ellipse().fill(.black.opacity(0.15))
            .frame(width: 60 - p.bodyDY * 0.4, height: 10)
            .blur(radius: 4)
            .offset(y: -4)
    }
}

/// A rounded-corner trapezoid for the torso (wider at the shoulders).
struct TorsoShape: Shape {
    var topW: CGFloat   // top width as a fraction of the rect
    var botW: CGFloat
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let tl = w * (1 - topW) / 2, tr = w * (1 + topW) / 2
        let bl = w * (1 - botW) / 2, br = w * (1 + botW) / 2
        let rad: CGFloat = 8
        var p = Path()
        p.move(to: CGPoint(x: tl + rad, y: 0))
        p.addLine(to: CGPoint(x: tr - rad, y: 0))
        p.addQuadCurve(to: CGPoint(x: tr, y: rad), control: CGPoint(x: tr, y: 0))
        p.addLine(to: CGPoint(x: br, y: h - rad))
        p.addQuadCurve(to: CGPoint(x: br - rad, y: h), control: CGPoint(x: br, y: h))
        p.addLine(to: CGPoint(x: bl + rad, y: h))
        p.addQuadCurve(to: CGPoint(x: bl, y: h - rad), control: CGPoint(x: bl, y: h))
        p.addLine(to: CGPoint(x: tl, y: rad))
        p.addQuadCurve(to: CGPoint(x: tl + rad, y: 0), control: CGPoint(x: tl, y: 0))
        p.closeSubpath()
        return p
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: 0))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

import SwiftUI

/// A side-profile head that shows one chin tuck on a loop: the head glides
/// straight back until the ear sits on the dashed line over the shoulder,
/// holds, then returns to level. Drawn in code, so it costs no assets and
/// keeps the PoseDiagram look. The faint outline marks where the head starts.
///
/// One cycle is 4 seconds, inside the 0.8 to 6 second window
/// `ChinTuckRepDetector` counts as a rep, so copying the pace lands reps.
/// Under Reduce Motion it holds the tucked pose with an arrow back from the
/// starting outline.
struct ChinTuckDemo: View {
    var height: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active)) { timeline in
            let tuck = reduceMotion ? 1 : Self.tuck(at: timeline.date.timeIntervalSince(startedAt))
            Canvas { ctx, size in
                draw(ctx, size: size, tuck: tuck)
            }
        }
        .frame(width: height * 1.3, height: height)
        .accessibilityElement()
        .accessibilityLabel("Chin tuck demonstration")
        .accessibilityAddTraits(.isImage)
        // Lets the fleet's idle-screen check skip it: it moves on purpose.
        .accessibilityIdentifier("chin-tuck-demo")
    }

    // MARK: - Timing

    private nonisolated static let rest = 0.8
    private nonisolated static let glide = 1.0
    private nonisolated static let hold = 1.2
    /// One loop of the demo, rest included.
    nonisolated static var cycle: Double { rest + glide + hold + glide }
    /// One rep as the detector sees it: leave level, hold, come back.
    nonisolated static var repSeconds: Double { glide + hold + glide }

    /// How far into the tuck the head is at `t` seconds: 0 level, 1 tucked.
    nonisolated static func tuck(at t: TimeInterval) -> Double {
        let phase = max(0, t).truncatingRemainder(dividingBy: cycle)
        switch phase {
        case ..<rest: return 0
        case ..<(rest + glide): return ease((phase - rest) / glide)
        case ..<(rest + glide + hold): return 1
        default: return 1 - ease((phase - rest - glide - hold) / glide)
        }
    }

    private nonisolated static func ease(_ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        return x * x * (3 - 2 * x)
    }

    // MARK: - Drawing

    private func draw(_ ctx: GraphicsContext, size: CGSize, tuck: Double) {
        let w = size.width, h = size.height
        let headR = h * 0.2
        let stroke = max(3, h * 0.045)
        let shoulder = CGPoint(x: w * 0.36, y: h * 0.84)
        let headY = h * 0.34
        // The ear sits a little behind the centre of the head.
        let earOffset = headR * 0.25
        let forward = w * 0.2
        let tuckedX = shoulder.x + earOffset
        let startX = tuckedX + forward
        let headX = startX - forward * CGFloat(tuck)
        let body = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)

        // Plumb line: where the ear should land, straight over the shoulder.
        var plumb = Path()
        plumb.move(to: CGPoint(x: shoulder.x, y: h * 0.04))
        plumb.addLine(to: CGPoint(x: shoulder.x, y: shoulder.y))
        ctx.stroke(plumb, with: .color(Theme.ink3.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))

        // Upper back rounding down from the shoulder.
        var back = Path()
        back.move(to: shoulder)
        back.addQuadCurve(to: CGPoint(x: shoulder.x - w * 0.16, y: h),
                          control: CGPoint(x: shoulder.x - w * 0.14, y: shoulder.y))
        ctx.stroke(back, with: .color(Theme.ink2), style: body)

        // Where the head starts, so the motion reads as "back from here".
        let ghost = headRect(x: startX, y: headY, r: headR)
        ctx.stroke(Circle().path(in: ghost), with: .color(Theme.ink3.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

        if reduceMotion {
            drawArrow(ctx, from: startX + headR * 0.4, to: tuckedX - headR * 0.2,
                      y: headY - headR * 1.25, stroke: stroke)
        }

        // Neck: shoulder to the base of the skull.
        var neck = Path()
        neck.move(to: shoulder)
        neck.addLine(to: CGPoint(x: headX - earOffset, y: headY + headR * 0.9))
        ctx.stroke(neck, with: .color(Theme.ink2), style: body)

        // Head stays level while it glides back, rather than nodding down.
        var head = ctx
        head.translateBy(x: headX, y: headY)
        var nose = Path()
        nose.move(to: CGPoint(x: headR * 0.8, y: -headR * 0.32))
        nose.addLine(to: CGPoint(x: headR * 1.3, y: headR * 0.05))
        nose.addLine(to: CGPoint(x: headR * 0.85, y: headR * 0.28))
        nose.closeSubpath()
        head.fill(nose, with: .color(Theme.lavender))
        head.fill(Circle().path(in: headRect(x: 0, y: 0, r: headR)), with: .color(Theme.lavender))

        // Ear marker, the point that lines up with the plumb line.
        let earR = h * 0.035
        let ear = headRect(x: headX - earOffset, y: headY, r: earR)
        ctx.fill(Circle().path(in: ear), with: .color(Theme.sand))
        ctx.stroke(Circle().path(in: ear), with: .color(Theme.paper), lineWidth: 1.5)
    }

    private func drawArrow(_ ctx: GraphicsContext, from start: CGFloat, to end: CGFloat,
                           y: CGFloat, stroke: CGFloat) {
        let head = stroke * 1.6
        var arrow = Path()
        arrow.move(to: CGPoint(x: start, y: y))
        arrow.addLine(to: CGPoint(x: end, y: y))
        arrow.move(to: CGPoint(x: end + head, y: y - head))
        arrow.addLine(to: CGPoint(x: end, y: y))
        arrow.addLine(to: CGPoint(x: end + head, y: y + head))
        ctx.stroke(arrow, with: .color(Theme.lavender),
                   style: StrokeStyle(lineWidth: stroke * 0.6, lineCap: .round, lineJoin: .round))
    }

    private func headRect(x: CGFloat, y: CGFloat, r: CGFloat) -> CGRect {
        CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
    }
}

#Preview {
    VStack(spacing: 32) {
        ChinTuckDemo()
        ChinTuckDemo(height: 140)
    }
    .padding()
    .background(Theme.paper)
}

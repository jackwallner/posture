import SwiftUI
import UIKit

/// Instructional pose visual for onboarding and calibration. A large figure
/// with a dashed plumb line and ear/shoulder/hip markers - teaches the
/// "stack" visually instead of describing it. Pure SwiftUI so it ships
/// without asset generation; designed to be swapped for illustrated art
/// later without changing call sites.
struct PoseDiagram: View {
    enum Pose {
        case standing
        case sitting
        case slouching
        case stack      // side-profile alignment teaching diagram
    }

    let pose: Pose
    var height: CGFloat = 180

    var body: some View {
        // Illustrated art wins when present in the asset catalog (generated
        // by scripts/generate-illustrations.py); the drawn diagram is the
        // no-assets fallback so the build never depends on generation.
        if let illustration = UIImage(named: assetName) {
            Image(uiImage: illustration)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
        } else {
            drawnDiagram
        }
    }

    private var assetName: String {
        switch pose {
        case .standing: return "IlloStanding"
        case .sitting: return "IlloSitting"
        case .slouching: return "IlloSlouch"
        case .stack: return "IlloStack"
        }
    }

    private var drawnDiagram: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(wash)
            Canvas { ctx, size in
                drawFigure(ctx, size: size)
            }
            .padding(height * 0.16)
        }
        .frame(width: height * 1.15, height: height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// A schematic side profile - head, spine, hips - so the drawing actually
    /// reads as a body. Aligned poses stack the head over the hips on the
    /// dashed plumb line; the slouch thrusts the head forward and rounds the
    /// upper back, which is exactly the shape we coach people out of.
    private func drawFigure(_ ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let stroke = max(3, h * 0.03)
        let hipX = w * 0.40
        let hipY = h * 0.80
        let shoulderY = h * 0.40
        let headR = h * 0.12
        let forward = CGFloat(forwardHead) * w
        let shoulderX = hipX + forward * 0.35
        let headX = hipX + forward
        let headY = shoulderY - headR * 1.5
        let body = GraphicsContext.Shading.color(Theme.ink2)
        let bodyStyle = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)

        // Plumb reference through the hips - the line a stacked spine follows.
        var plumb = Path()
        plumb.move(to: CGPoint(x: hipX, y: h * 0.10))
        plumb.addLine(to: CGPoint(x: hipX, y: hipY))
        ctx.stroke(plumb, with: .color(Theme.ink3.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))

        // Legs (standing) or thigh + shin (seated).
        var legs = Path()
        legs.move(to: CGPoint(x: hipX, y: hipY))
        if seated {
            legs.addLine(to: CGPoint(x: hipX + w * 0.34, y: hipY))
            legs.addLine(to: CGPoint(x: hipX + w * 0.34, y: h * 0.97))
        } else {
            legs.addLine(to: CGPoint(x: hipX, y: h * 0.97))
        }
        ctx.stroke(legs, with: body, style: bodyStyle)

        // Spine: hip → shoulder, bowing forward as the slouch deepens.
        var spine = Path()
        spine.move(to: CGPoint(x: hipX, y: hipY))
        spine.addQuadCurve(
            to: CGPoint(x: shoulderX, y: shoulderY),
            control: CGPoint(x: hipX + forward * 0.85, y: (hipY + shoulderY) / 2)
        )
        ctx.stroke(spine, with: body, style: bodyStyle)

        // Neck: shoulder → base of the head.
        var neck = Path()
        neck.move(to: CGPoint(x: shoulderX, y: shoulderY))
        neck.addLine(to: CGPoint(x: headX, y: headY + headR))
        ctx.stroke(neck, with: body, style: bodyStyle)

        // Head.
        let headRect = CGRect(x: headX - headR, y: headY - headR, width: headR * 2, height: headR * 2)
        ctx.fill(Circle().path(in: headRect), with: .color(accent))

        // Ear / shoulder / hip markers - aligned they sit on the plumb line,
        // slouched the ear marker breaks forward of it.
        for pt in [CGPoint(x: headX, y: headY), CGPoint(x: shoulderX, y: shoulderY), CGPoint(x: hipX, y: hipY)] {
            let r = h * 0.024
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            ctx.fill(Circle().path(in: rect), with: .color(Theme.sand))
            ctx.stroke(Circle().path(in: rect), with: .color(Theme.paper), lineWidth: 1.5)
        }
    }

    /// How far forward of the plumb line the head sits (fraction of width).
    private var forwardHead: Double {
        pose == .slouching ? 0.20 : 0
    }

    private var seated: Bool {
        pose == .sitting || pose == .slouching
    }

    private var accent: Color {
        pose == .slouching ? Theme.clay : Theme.sage
    }

    private var wash: Color {
        pose == .slouching ? Theme.clayTint : Theme.sageTint
    }
}

#Preview {
    VStack(spacing: 24) {
        PoseDiagram(pose: .stack)
        PoseDiagram(pose: .sitting)
        PoseDiagram(pose: .slouching, height: 140)
    }
    .padding()
    .background(Theme.paper)
}

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
            Circle()
                .fill(wash)
                .frame(width: height, height: height)

            if showsPlumbLine {
                plumbLine
                    .frame(height: height * 0.78)
            }

            Image(systemName: symbolName)
                .font(.system(size: height * 0.42, weight: .light))
                .foregroundStyle(accent)

            if showsPlumbLine {
                alignmentDots
                    .frame(height: height * 0.62)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch pose {
        case .standing: return "figure.stand"
        case .sitting: return "figure.seated.side"
        case .slouching: return "figure.seated.side"
        case .stack: return "figure.stand"
        }
    }

    private var accent: Color {
        pose == .slouching ? Theme.clay : Theme.sage
    }

    private var wash: Color {
        pose == .slouching ? Theme.clayTint : Theme.sageTint
    }

    private var showsPlumbLine: Bool {
        pose == .stack || pose == .standing
    }

    /// The dashed "thread" through ear, shoulder, hip.
    private var plumbLine: some View {
        Rectangle()
            .fill(.clear)
            .overlay(
                Line()
                    .stroke(
                        Theme.ink2.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 5])
                    )
            )
            .frame(width: 2)
    }

    /// Ear / shoulder / hip markers on the plumb line.
    private var alignmentDots: some View {
        VStack {
            dot
            Spacer()
            dot
            Spacer()
            dot
        }
    }

    private var dot: some View {
        Circle()
            .fill(Theme.sand)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Theme.paper2, lineWidth: 1.5))
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return p
        }
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

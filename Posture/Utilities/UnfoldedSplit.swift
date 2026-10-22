import SwiftUI

/// Pane frames for the unfolded iPhone Duo: Today and the other tabs on the
/// leading side of the fold, History on the trailing side, so nothing straddles
/// the crease. `nil` keeps the single column (every ordinary iPhone, the folded
/// Duo, and the unfolded Duo held in portrait, where each half is too narrow).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the compact Today and History layouts.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }
}

/// The container's width and fold, measured together so one geometry change
/// moves both panes.
struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?
}

extension GeometryProxy {
    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}

extension View {
    /// Measures this view's width and fold into `geometry`.
    func measuresPaneGeometry(_ geometry: Binding<PaneGeometry>) -> some View {
        onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { geometry.wrappedValue = $0 }
    }

    /// One pane of the unfolded split lays out as on a phone. iOS 27.1 can also
    /// move a stack's back button and toolbar items into a vertical bar on its
    /// trailing edge, which in a pane lands beside the fold; a pane keeps the
    /// phone's horizontal bar. Folded, both stay the system default.
    @ViewBuilder
    func phonePane(isSplit: Bool, sizeClass: UserInterfaceSizeClass?) -> some View {
        if #available(iOS 27.1, *) {
            environment(\.horizontalSizeClass, sizeClass)
                .toolbarVerticalBehavior(isSplit ? .disabled : .automatic)
        } else {
            environment(\.horizontalSizeClass, sizeClass)
        }
    }

    /// Unfolded, the tab bar floats along the bottom of the leading pane. A
    /// tab's content fades out just above the bar, so the bar sits on the page
    /// wash with nothing behind it, and scrolling to the end still clears the
    /// fade. Folded keeps the system default (content scrolls under the bar).
    func unfoldedBarClearance(isSplit: Bool) -> some View {
        modifier(UnfoldedBarClearance(isSplit: isSplit))
    }

    /// Keeps a single-column setup screen (onboarding, calibration) on the
    /// leading side of the fold and puts `trailing` in the other pane.
    func unfoldedLeadingPane<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(UnfoldedLeadingPane(trailing: trailing()))
    }
}

/// Every other width shows the screen as it is. Only frames change, so a fold
/// mid-step keeps the screen's state.
private struct UnfoldedLeadingPane<Trailing: View>: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var geometry = PaneGeometry()
    let trailing: Trailing

    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(width: geometry.width, isRegularWidth: horizontalSizeClass == .regular, fold: geometry.fold)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            // Behind the fold, which neither pane covers.
            Theme.dawnWash.ignoresSafeArea()
            content
                .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)
            trailing
                .environment(\.horizontalSizeClass, .compact)
                .frame(width: split?.secondaryWidth ?? 0)
                .frame(maxHeight: .infinity)
                .padding(.leading, split?.secondaryX ?? 0)
                .opacity(split == nil ? 0 : 1)
                .accessibilityHidden(split == nil)
        }
        .measuresPaneGeometry($geometry)
    }
}

/// See `unfoldedBarClearance(isSplit:)`. The mask stays in place folded (fully
/// open there), so folding never rebuilds the tab's content.
private struct UnfoldedBarClearance: ViewModifier {
    let isSplit: Bool
    @State private var bottomInset: CGFloat = 0

    /// Height of the fade between the content and the bar.
    static let fade: CGFloat = 28
    /// Space between the fade and the bar's safe-area edge.
    static let gap: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, isSplit ? Self.fade + Self.gap : 0)
            .scrollEdgeEffectHiddenIfAvailable(isSplit)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: isSplit ? Self.fade : 0)
                    Color.clear
                        .frame(height: isSplit ? bottomInset + Self.gap : 0)
                }
                .ignoresSafeArea()
            }
            .background(Theme.dawnWash.ignoresSafeArea())
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
    }
}

private extension View {
    @ViewBuilder
    func scrollEdgeEffectHiddenIfAvailable(_ hidden: Bool) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(hidden, for: .bottom)
        } else {
            self
        }
    }
}

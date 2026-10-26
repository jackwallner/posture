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
    /// tab's content stops a gap above the bar, cut between whole rows (see
    /// `PaneCut`), so the bar sits on the page wash with nothing behind it.
    /// The History pane uses it too, so no row is sliced at the screen edge.
    /// Folded keeps the system default (content scrolls under the bar).
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
            // Built only when split: at zero width its wrapping text grew
            // taller than the screen and pushed the phone layout off it.
            if let split {
                trailing
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(width: split.secondaryWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .measuresPaneGeometry($geometry)
    }
}

/// Heights for a pane's clearance above its floating tab bar (the History
/// pane: above the home indicator). Split, content ends `gap` above the bar's
/// safe-area edge, and a bottom scroll content margin of `gap` lets the last
/// row scroll up to that line. Folded, both are zero and the phone layout is
/// untouched.
struct TabBarClearance: Equatable, Sendable {
    /// Masked out from the bottom: the bar's inset plus the gap.
    var hidden: CGFloat
    /// Bottom scroll content margin, so a scrolled-to-end row meets the line.
    var contentPadding: CGFloat

    static let gap: CGFloat = 12

    static func make(isSplit: Bool, barInset: CGFloat) -> TabBarClearance {
        guard isSplit else { return TabBarClearance(hidden: 0, contentPadding: 0) }
        return TabBarClearance(hidden: max(barInset, 0) + gap, contentPadding: gap)
    }
}

/// Where a pane's content stops above its bar. A row the clearance line would
/// slice is hidden whole instead: the cut moves up to that row's top, so the
/// pane never shows half a card or a ghost of one fading out. A row that
/// starts more than `maxLift` above the line is sliced at the line rather
/// than leave the pane mostly empty.
struct PaneCut: Equatable, Sendable {
    /// In the same space as the rows' frames.
    var y: CGFloat
    /// The cut runs between two rows of this card, so the card gets rounded
    /// bottom corners there, as if it ended. `nil` between cards.
    var card: Card?

    /// A card whose rows report one by one: its inset from the pane edge
    /// and its corner radius.
    struct Card: Equatable, Sendable {
        var inset: CGFloat
        var cornerRadius: CGFloat

        /// An inset grouped Form section.
        static let groupedList = Card(inset: 20, cornerRadius: 24)
    }

    struct Row: Equatable, Sendable {
        var minY: CGFloat
        var maxY: CGFloat
        var card: Card?
    }

    static let maxLift: CGFloat = 220
    /// How far above a hidden row the cut runs: a card's 1 pt stroke straddles
    /// its top edge and a divider sits just above a row, and a cut at the edge
    /// left either as a hairline.
    static let margin: CGFloat = 2

    static func make(line: CGFloat, rows: some Sequence<Row>) -> PaneCut {
        let sliced = rows.filter { row in
            row.minY < line - 0.5 && row.maxY > line + 0.5 && line - row.minY <= maxLift
        }
        guard let first = sliced.min(by: { $0.minY < $1.minY }) else {
            return PaneCut(y: line, card: nil)
        }
        return PaneCut(y: first.minY - margin, card: first.card)
    }
}

extension EnvironmentValues {
    /// The split pane's row frames, for `PaneCut`. `nil` folded, so the phone
    /// layout does no bookkeeping while it scrolls.
    @Entry var paneRows: PaneRows? = nil
}

/// Row frames reported by `paneRow()` and read by the pane's mask.
@MainActor @Observable
final class PaneRows {
    var rows: [UUID: PaneCut.Row] = [:]
}

extension View {
    /// A whole card or line the pane cut hides rather than slices.
    /// `keepWithNext` holds a section header back with its first row.
    func paneRow(keepWithNext: CGFloat = 0) -> some View {
        modifier(PaneRowReporter(keepWithNext: keepWithNext, card: nil))
    }

    /// The rows of an inset grouped Form section. Each reports its cell's
    /// frame through the row background, which fills the cell.
    func paneListRows() -> some View {
        modifier(PaneListRows())
    }
}

/// A column whose children each count as a whole pane row, so the pane cut
/// never slices one of its cards.
struct PaneRowStack<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 18.0, *) {
            VStack(alignment: alignment, spacing: spacing) {
                ForEach(subviews: content) { $0.paneRow() }
            }
        } else {
            VStack(alignment: alignment, spacing: spacing) { content }
        }
    }
}

/// See `unfoldedBarClearance(isSplit:)`, `TabBarClearance` and `PaneCut`. The
/// mask stays in place folded (fully open there), so folding never rebuilds
/// the tab's content.
private struct UnfoldedBarClearance: ViewModifier {
    let isSplit: Bool
    @State private var barInset: CGFloat = 0
    @State private var rows = PaneRows()

    private var clearance: TabBarClearance {
        .make(isSplit: isSplit, barInset: barInset)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.paneRows, isSplit ? rows : nil)
            // A scroll content margin reaches the scroll view inside each
            // tab's NavigationStack. Folded, nil keeps each container's own.
            .contentMargins(.bottom, isSplit ? clearance.contentPadding : nil, for: .scrollContent)
            .scrollEdgeEffectHiddenIfAvailable(isSplit)
            .mask {
                PaneCutMask(rows: rows, hidden: clearance.hidden, isSplit: isSplit)
                    .ignoresSafeArea()
            }
            // The bar floats on the page wash, not on a cut-off row.
            .background(Theme.dawnWash.ignoresSafeArea())
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { barInset = $0 }
    }
}

private struct PaneCutMask: View {
    let rows: PaneRows
    let hidden: CGFloat
    let isSplit: Bool

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let cut = isSplit
                ? PaneCut.make(line: frame.maxY - hidden, rows: rows.rows.values)
                : PaneCut(y: frame.maxY, card: nil)
            let y = min(max(cut.y - frame.minY, 0), frame.height)
            let radius = cut.card.map { min($0.cornerRadius, y / 2) } ?? 0
            // Two overlapping shapes rather than one path, so no seam shows
            // where the straight part meets the rounded card bottom.
            ZStack(alignment: .top) {
                Rectangle().frame(height: y - radius)
                if radius > 0 {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: radius,
                        bottomTrailingRadius: radius,
                        style: .continuous
                    )
                    .frame(height: radius * 2)
                    .padding(.horizontal, cut.card?.inset ?? 0)
                    .offset(y: y - radius * 2)
                }
            }
            .frame(width: frame.width, height: frame.height, alignment: .top)
        }
    }
}

private struct PaneRowReporter: ViewModifier {
    let keepWithNext: CGFloat
    let card: PaneCut.Card?
    @Environment(\.paneRows) private var paneRows
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                let row = PaneCut.Row(minY: frame.minY, maxY: frame.maxY + keepWithNext, card: card)
                if paneRows?.rows[id] != row { paneRows?.rows[id] = row }
            }
            .onDisappear { paneRows?.rows[id] = nil }
    }
}

private struct PaneListRows: ViewModifier {
    @Environment(\.paneRows) private var paneRows

    func body(content: Content) -> some View {
        // Folded, the system's own row background, untouched.
        content.listRowBackground(
            paneRows.map { _ in
                Color(.secondarySystemGroupedBackground)
                    .modifier(PaneRowReporter(keepWithNext: 0, card: .groupedList))
            }
        )
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

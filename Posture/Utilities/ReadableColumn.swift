import SwiftUI

extension View {
    /// Caps the content at a readable width and centres it in the space the
    /// container gives it. On an iPhone the cap is never reached, so nothing
    /// changes there; on an iPad it keeps lines and cards from stretching
    /// across a 13-inch screen.
    func readableColumn(maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// A full-screen cover's content in a readable column on the page wash:
    /// the wash fills the screen, the content keeps phone proportions.
    func dawnColumn(maxWidth: CGFloat = 560) -> some View {
        readableColumn(maxWidth: maxWidth).dawnBackground()
    }
}

extension View {
    /// A tab's content as one readable column on an iPad that is too narrow
    /// for the Today and History panes. Never rebuilds the view: the frame is
    /// always there and only its cap changes. Everywhere else it is a no-op.
    func iPadSingleColumn(_ active: Bool, maxWidth: CGFloat = 680) -> some View {
        let capped = active && UIDevice.current.userInterfaceIdiom == .pad
        return frame(maxWidth: capped ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
            // The tab view paints the system background beside a capped column.
            .background { if capped { Theme.dawnWash.ignoresSafeArea() } }
    }
}

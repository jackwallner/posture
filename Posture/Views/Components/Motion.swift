import SwiftUI
import UIKit

/// withAnimation that stands down when Reduce Motion is on.
@MainActor
func withMotion<T>(_ animation: Animation? = .default, _ body: () throws -> T) rethrows -> T {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : animation, body)
}

extension View {
    /// .animation(_:value:) that stands down when Reduce Motion is on.
    func motion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.animation(UIAccessibility.isReduceMotionEnabled ? nil : animation, value: value)
    }
}

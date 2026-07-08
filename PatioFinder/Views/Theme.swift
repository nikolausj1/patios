import SwiftUI
import UIKit

/// Warm terracotta / amber palette — Find-My-inspired but distinct.
enum Theme {
    static let accent      = Color("AccentColor")                 // terracotta (asset)
    static let accentBright = Color(red: 0.98, green: 0.70, blue: 0.35) // amber highlight
    static let accentDeep  = Color(red: 0.78, green: 0.34, blue: 0.20) // deep terracotta

    /// Adaptive page background: near-white in light, near-black in dark.
    static let background = Color(uiColor: .systemBackground)
    static let secondaryText = Color(uiColor: .secondaryLabel)
}

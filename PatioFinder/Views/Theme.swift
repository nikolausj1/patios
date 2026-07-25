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

    /// Warm sunset wash behind the whole screen — cream in light, ember-dark in dark.
    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color(uiColor: bgTop), Color(uiColor: bgBottom)],
                       startPoint: .top, endPoint: .bottom)
    }

    private static let bgTop = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.08, blue: 0.07, alpha: 1)
            : UIColor(red: 1.00, green: 0.97, blue: 0.93, alpha: 1)
    }
    private static let bgBottom = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.04, blue: 0.04, alpha: 1)
            : UIColor(red: 0.99, green: 0.91, blue: 0.83, alpha: 1)
    }
}

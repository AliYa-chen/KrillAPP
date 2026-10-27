import SwiftUI

/// Native toolbars size their glass background from the label's ideal size.
/// Keep both states in the same fixed box so a spinner cannot expand the capsule.
struct RefreshControlLabel: View {
    let isRefreshing: Bool

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: 18, weight: .medium))
            .opacity(isRefreshing ? 0 : 1)
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
                    .fixedSize()
                    .opacity(isRefreshing ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(width: 24, height: 24)
            .clipped()
            .animation(nil, value: isRefreshing)
    }
}

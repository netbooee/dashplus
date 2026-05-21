import SwiftUI

struct CompletedArchiveDivider: View {
    var title: String = "Completed"
    let isCollapsed: Bool
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 0.5)
                HStack(spacing: 4) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                    Text(isCollapsed ? "\(title) (\(count))" : title)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

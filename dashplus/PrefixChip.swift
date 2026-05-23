import SwiftUI

/// Outlined terracotta prefix badge — used in list headers and item rows.
struct PrefixChip: View {
    let prefix: String
    /// Use `large` for list/project section headers; default (false) for inline item rows.
    var large: Bool = false

    var body: some View {
        if !prefix.isEmpty {
            Text(prefix)
                .font(.system(size: large ? 11 : 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, large ? 6 : 5)
                .padding(.vertical, large ? 2 : 2)
                .overlay {
                    RoundedRectangle(cornerRadius: large ? 5 : 4)
                        .stroke(Color.appAccent, lineWidth: 1)
                }
        }
    }
}

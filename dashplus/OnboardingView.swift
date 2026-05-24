import SwiftUI

// MARK: - Page model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let detail: String?
}

// MARK: - Symbol row (used on the symbols page)

private struct SymbolRow: View {
    let symbol: ItemSymbol
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol.systemImageName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(symbol.color)
                .frame(width: 32, height: 32)
                .background(symbol.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Individual pages

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.appAccent)
                        .frame(width: 100, height: 100)
                    Text("−")
                        .font(.system(size: 56, weight: .thin, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.appAccent.opacity(0.4), radius: 16, x: 0, y: 8)

                VStack(spacing: 8) {
                    Text("Welcome to HappensNext")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("A symbol-based system for capturing everything — tasks, meetings, notes, ideas — and always knowing your next action.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct SymbolsPage: View {
    private let rows: [(ItemSymbol, String)] = [
        (.dash,             "Something that needs to be done"),
        (.square,           "A meeting that needs scheduling"),
        (.scheduledMeeting, "A meeting with a confirmed date"),
        (.leftArrow,        "Handed off — tracking who has it"),
        (.rightArrow,       "Waiting on someone else"),
        (.triangle,         "A thought, reference, or note"),
        (.person,           "A person or contact to follow up"),
        (.someday,          "Captured, but not yet committed"),
        (.plus,             "Done — the loop is closed"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("The Symbol System")
                    .font(.title.weight(.bold))
                Text("The mark carries the meaning. One tap changes what an item is.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.0) { symbol, desc in
                    SymbolRow(symbol: symbol, description: desc)
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimelinePage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(Color.appAccent)

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Your Timeline")
                        .font(.title.weight(.bold))
                    Text("Today is always first. Everything captured without a date lives here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 16) {
                    TimelineFeatureRow(
                        icon: "arrow.right.circle.fill",
                        color: .orange,
                        title: "Set a Start Date",
                        detail: "Move any item to a future date. It disappears from Today and reappears when the time comes."
                    )
                    TimelineFeatureRow(
                        icon: "calendar.badge.exclamationmark",
                        color: .red,
                        title: "Add a Due Date",
                        detail: "Track deadlines without affecting where the item lives in your timeline."
                    )
                    TimelineFeatureRow(
                        icon: "chevron.down.circle.fill",
                        color: Color.appAccent,
                        title: "Collapse & Focus",
                        detail: "Tap any day header to collapse it. Tap a date chip to focus just that day."
                    )
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct TimelineFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ProjectsPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            HStack(spacing: 16) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(Color.appAccent)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(Color.appAccent.opacity(0.5))
            }

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Projects & Dashboard")
                        .font(.title.weight(.bold))
                    Text("Organize items into projects. See the big picture at a glance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 16) {
                    TimelineFeatureRow(
                        icon: "folder.badge.plus",
                        color: Color.appAccent,
                        title: "Projects",
                        detail: "Group related items under a named project with a short prefix code like REC or GEN."
                    )
                    TimelineFeatureRow(
                        icon: "chart.bar.xaxis",
                        color: .blue,
                        title: "Dashboard",
                        detail: "Live counts of every symbol type. Tap any tile to see all items of that kind."
                    )
                    TimelineFeatureRow(
                        icon: "square.and.arrow.up",
                        color: .teal,
                        title: "Import & Export",
                        detail: "Share lists as plain text files. Import from any plain-text Dash/Plus log."
                    )
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

private struct GetStartedPage: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.appAccent)

            VStack(spacing: 10) {
                Text("You're ready.")
                    .font(.largeTitle.weight(.bold))
                Text("Capture everything. Clarify what it means.\nAlways know your next act.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    let onDismiss: () -> Void
    @State private var page = 0

    private let pageCount = 5

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.warmBg.ignoresSafeArea()

            TabView(selection: $page) {
                WelcomePage()
                    .tag(0)
                SymbolsPage()
                    .tag(1)
                TimelinePage()
                    .tag(2)
                ProjectsPage()
                    .tag(3)
                GetStartedPage(onDismiss: onDismiss)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            // Custom page dots + next button
            if page < pageCount - 1 {
                VStack(spacing: 20) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Color.appAccent : Color.appAccent.opacity(0.25))
                                .frame(width: i == page ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }

                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text(page == 0 ? "Get Started" : "Next")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

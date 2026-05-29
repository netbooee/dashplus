import SwiftUI

// MARK: - FAQ model

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String

    static let all: [FAQItem] = [
        FAQItem(
            question: "What is HappensNext?",
            answer: "HappensNext is a symbol-based productivity system for capturing everything life throws at you — tasks, meetings, notes, ideas, and people — and always knowing your next action. Every item gets a symbol that shows its type and status at a glance."
        ),
        FAQItem(
            question: "What do the symbols mean?",
            answer: "– (dash) = to-do or next action\n+ (plus) = completed\n→ (right arrow) = waiting for someone or something\n← (left arrow) = delegated to someone else\n□ (square) = meeting that needs scheduling\n□+ (calendar) = meeting already scheduled\n△ (triangle) = note or reference\nP (person) = new contact\n☽ (moon) = someday / maybe idea"
        ),
        FAQItem(
            question: "How do I add an item?",
            answer: "Tap 'What happens next?' at the bottom of any project to quickly add a to-do. Tap the + button on the main screen for a full entry form with symbol, dates, and project selection. Or use the mic button to capture a free-form note and let AI extract the items for you."
        ),
        FAQItem(
            question: "How do I change an item's symbol or project?",
            answer: "Tap the symbol icon on the left of any item to open the symbol picker. From there you can change the type, set start or due dates, assign a delegate, and switch the item to a different project — all without leaving the screen."
        ),
        FAQItem(
            question: "What does the AI note capture do?",
            answer: "Tap the microphone icon on the main screen. Speak or type freely — describe your meetings, tasks, and ideas in plain language. Tap 'Process Note' and the AI extracts individual items, assigns the right symbols, suggests projects, and picks up any dates you mention. Review everything before saving."
        ),
        FAQItem(
            question: "How do I get an Anthropic API key?",
            answer: "Visit console.anthropic.com, create a free account, and generate a key under 'API Keys'. New accounts receive free credits — enough for hundreds of note captures. Paste the key in the AI Note Capture section in these Settings."
        ),
        FAQItem(
            question: "How do I mark an item complete?",
            answer: "Tap the symbol icon on any item and select the + (Complete) symbol. You'll hear a chime confirming the action. Completed items move to the Completed section at the bottom of each project view."
        ),
        FAQItem(
            question: "How do I delete an item?",
            answer: "On the main screen, swipe left on any item to reveal a Delete button, or long-press for a context menu. In project detail views, swipe left on any item in the list."
        ),
        FAQItem(
            question: "How do I back up my data?",
            answer: "Go to Projects → ⋯ menu → Export All Projects. This creates a single text file with all your projects and items. To restore, use the same menu → Import Projects and select the backup file. The app automatically detects whether the file is a full backup or a single-project export."
        ),
        FAQItem(
            question: "Does HappensNext sync across devices?",
            answer: "Yes — the app syncs automatically via iCloud if you're signed in with the same Apple ID. Your projects, items, and settings stay in sync across all your Apple devices."
        ),
        FAQItem(
            question: "What is Someday / Maybe?",
            answer: "The moon-and-stars symbol is for ideas you want to revisit later but aren't ready to act on yet. These items collect in their own collapsible section in each project, kept separate from your active tasks."
        ),
    ]
}

// MARK: - SettingsView

struct SettingsView: View {
    @AppStorage("happensnext.hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("happensnext.anthropicAPIKey")   private var savedKey = ""

    @Environment(\.dismiss) private var dismiss

    @State private var keyDraft = ""
    @State private var isRevealingKey = false
    @State private var keySaved = false

    var body: some View {
        NavigationStack {
            Form {

                // MARK: General
                Section("General") {
                    Button {
                        hasSeenOnboarding = false
                        dismiss()
                    } label: {
                        Label("Show Welcome Screen Again", systemImage: "sparkles")
                            .foregroundStyle(.primary)
                    }
                }

                // MARK: AI Note Capture
                Section {
                    HStack {
                        Group {
                            if isRevealingKey {
                                TextField("sk-ant-…", text: $keyDraft)
                            } else {
                                SecureField("sk-ant-…", text: $keyDraft)
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: keyDraft) { _, _ in keySaved = false }

                        Button { isRevealingKey.toggle() } label: {
                            Image(systemName: isRevealingKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        savedKey = keyDraft.trimmingCharacters(in: .whitespaces)
                        keySaved = true
                    } label: {
                        HStack {
                            Text(keySaved ? "Key Saved" : "Save Key")
                            Spacer()
                            if keySaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .foregroundStyle(keySaved ? .secondary : Color.appAccent)
                    .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)

                    Link(destination: URL(string: "https://console.anthropic.com")!) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Get a free API key")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appAccent)
                                Text("console.anthropic.com → Sign up → API Keys")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                } header: {
                    Text("AI Note Capture")
                } footer: {
                    Text("Your key is stored locally on this device only. New Anthropic accounts receive free credits — enough for hundreds of note captures.")
                }

                // MARK: Help & FAQ
                Section("Help & FAQ") {
                    ForEach(FAQItem.all) { faq in
                        DisclosureGroup {
                            Text(faq.answer)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 6)
                        } label: {
                            Text(faq.question)
                                .font(.subheadline)
                        }
                    }
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.1")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("iCloud Sync")
                        Spacer()
                        Text(UserDefaults.standard.string(forKey: "happensnext.cloudKitStatus") ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                    if let error = UserDefaults.standard.string(forKey: "happensnext.cloudKitError") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { keyDraft = savedKey }
        }
    }
}

import TipKit

// MARK: - Shared gate

/// Set to true when the user finishes onboarding so tips are never shown
/// on top of the welcome screen.
private enum TipGate {
    @Parameter static var onboardingComplete: Bool = false
}

// MARK: - Home screen tip

/// Shown once on the first dashItem row in HomeView.
struct DeleteItemTip: Tip {

    var title: Text { Text("Managing items") }
    var message: Text? {
        Text("Swipe left on any item to delete it, or long-press for more options.")
    }
    var image: Image? { Image(systemName: "hand.draw.fill") }

    var rules: [Rule] {
        #Rule(TipGate.$onboardingComplete) { $0 == true }
    }

    /// Call this once onboarding is complete (and again on every cold launch
    /// for users who already skipped onboarding before this version shipped).
    static func unlockAfterOnboarding() {
        TipGate.onboardingComplete = true
    }
}

// MARK: - Projects screen tip

/// Shown once on the first project tile in ListsView.
struct ManageProjectTip: Tip {

    var title: Text { Text("Managing projects") }
    var message: Text? {
        Text("Long-press any project tile to edit or delete it.")
    }
    var image: Image? { Image(systemName: "hand.tap.fill") }

    var rules: [Rule] {
        #Rule(TipGate.$onboardingComplete) { $0 == true }
    }
}

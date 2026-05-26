import TipKit

/// Shown once on the first dashItem row in HomeView.
/// Teaches users that swipe-left deletes and long-press shows more options.
struct DeleteItemTip: Tip {
    var title: Text {
        Text("Managing items")
    }
    var message: Text? {
        Text("Swipe left on any item to delete it, or long-press to see more options.")
    }
    var image: Image? {
        Image(systemName: "hand.draw.fill")
    }
}

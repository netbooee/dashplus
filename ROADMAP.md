# Dash Plus — Feature Roadmap

Features under consideration for future development.

---

## AI Note Parser

**Summary:** Scan a photo of handwritten or printed notes and automatically create tasks in the appropriate lists.

**How it would work:**
- User taps a camera/photo button (likely in the QuickEntry sheet or toolbar)
- Image is sent to a vision model (e.g. Claude via the Anthropic API) with a prompt instructing it to extract Dash Plus items
- The model returns structured data: symbol, text, category code, and any metadata (assignedTo, waitingFor, scheduledDate)
- Items are inserted into the selected list (or auto-routed by prefix if the model detects one)

**Open questions:**
- Where does the entry point live — QuickEntrySheet, HomeView FAB, or DashListView toolbar?
- Should unrecognized prefixes create a new list or fall back to GEN?
- On-device (Vision framework OCR → local parse) vs. cloud (send image to Claude API)?
- How to handle review/confirm step before committing items — probably a preview sheet

**Dependencies:** Anthropic API key management, privacy prompt for camera/photo library access

---

## Completed Items — Compact Archive Display

**Summary:** In list views (DashListView and ListsView expanded sections), completed items should visually recede into an archive zone rather than sitting inline at full size.

**How it would work:**
- A subtle labeled divider (e.g. "— Completed —") separates active items from done items
- Completed items render at a smaller font size (caption or caption2) with reduced row padding
- Combined with the existing gray foreground, this creates a clear visual hierarchy: active items are prominent, done items are compact and muted at the bottom

**Open questions:**
- Should the archive section be collapsible (tap divider to hide/show completed items)?
- Apply to ListsView expanded sections only, or also to the full DashListView?
- Divider style — plain text label, a thin line with text, or a section header?

---

## Delegation Timestamp

**Summary:** Faithful to the original Dash/Plus system, which tracks WHO *and* WHEN alongside delegated (left-arrow) items. Currently the app only records the person's name.

**How it would work:**
- Add a `delegatedAt: Date` field to `DashItem` (defaults to the moment the symbol is set to `.leftArrow`)
- Display alongside the `@Name` annotation — e.g. `@Alice · May 21`
- In the People view, show the delegation date under each item for at-a-glance aging

**Open questions:**
- Should `delegatedAt` auto-set when the symbol changes to `.leftArrow`, or let the user pick a date?
- Display format: relative ("3 days ago") vs. absolute ("May 21")?

---

## Move Item to Another List

**Summary:** Faithful to the original circle symbol concept — a circled item means it has been carried forward or moved to a different list. Let the user reassign an item to any list and mark it with the circle symbol.

**How it would work:**
- In the symbol picker, selecting `.circle` triggers a follow-on list picker instead of (or after) confirming
- The item's `list` relationship is updated to the chosen list
- The symbol is set to `.circle` as a visual record that it was moved
- Optionally, a ghost/reference row stays in the original list showing "→ moved to [List]"

**Open questions:**
- Should the move be immediate (picker → list picker → done) or a separate swipe action?
- Keep a reference in the original list or just silently move?
- If moved to a list the user doesn't own yet, should it create the list?

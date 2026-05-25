import SwiftUI
import SwiftData
import Speech
import AVFoundation

// MARK: - SpeechTranscriber

@Observable
final class SpeechTranscriber {
    var transcript: String = ""
    var isListening: Bool = false
    var permissionDenied: Bool = false

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    func start() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else { self?.permissionDenied = true; return }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else { self?.permissionDenied = true; return }
                        try? self?.beginRecognition()
                    }
                }
            }
        }
    }

    func stop() {
        engine.stop()
        let inputNode = engine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        DispatchQueue.main.async { self.isListening = false }
    }

    private func beginRecognition() throws {
        task?.cancel(); task = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        try engine.start()
        DispatchQueue.main.async { self.isListening = true }

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            if let result {
                DispatchQueue.main.async { self?.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || result?.isFinal == true { self?.stop() }
        }
    }
}

// MARK: - NoteProcessorSheet

struct NoteProcessorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DashList.prefix) private var lists: [DashList]

    @AppStorage("happensnext.anthropicAPIKey") private var apiKey = ""

    @State private var transcriber = SpeechTranscriber()
    /// Editable text — speech results are merged in here.
    @State private var noteText = ""
    /// Snapshot of noteText when dictation started, so appended speech doesn't clobber typed text.
    @State private var textBeforeDictation = ""

    @State private var isProcessing = false
    @State private var extractedItems: [ExtractedItem] = []
    @State private var phase: Phase = .dictating
    @State private var errorMessage: String?
    @State private var showingAPIKeySheet = false

    private enum Phase { case dictating, reviewing }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch phase {
                case .dictating:  dictatingView
                case .reviewing:  reviewingView
                }
            }
            .navigationTitle(phase == .dictating ? "Capture Note" : "Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .reviewing ? "Back" : "Cancel") {
                        if phase == .reviewing {
                            withAnimation { phase = .dictating }
                        } else {
                            transcriber.stop()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAPIKeySheet = true } label: {
                        Image(systemName: "key")
                            .foregroundStyle(apiKey.isEmpty ? Color.red : Color.secondary)
                    }
                }
            }
        }
        .onChange(of: transcriber.transcript) { _, new in
            let prefix = textBeforeDictation.isEmpty ? "" : textBeforeDictation + " "
            noteText = prefix + new
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in Text(msg) }
        .alert("Permission Required", isPresented: $transcriber.permissionDenied) {
            Button("OK") { }
        } message: {
            Text("Please enable microphone and speech recognition in Settings to use dictation.")
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySheet(apiKey: $apiKey)
        }
        .onDisappear { transcriber.stop() }
    }

    // MARK: Dictating view

    private var dictatingView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $noteText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.warmBg)
                    .padding(8)

                if noteText.isEmpty {
                    Text("Tap the mic and speak, or type your thoughts here…")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 22)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(spacing: 14) {
                // Mic button
                Button {
                    if transcriber.isListening {
                        transcriber.stop()
                    } else {
                        textBeforeDictation = noteText
                        transcriber.transcript = ""
                        transcriber.start()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: transcriber.isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 28))
                            .symbolEffect(.pulse, isActive: transcriber.isListening)
                        Text(transcriber.isListening ? "Stop Dictating" : "Start Dictating")
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(transcriber.isListening ? .red : Color.appAccent)
                }

                // Process button
                Button { processNote() } label: {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView().tint(.white).scaleEffect(0.9)
                        }
                        Text(isProcessing ? "Processing…" : "Process Note")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canProcess && !isProcessing ? Color.appAccent : Color(.systemGray4))
                    .foregroundStyle(canProcess && !isProcessing ? .white : Color(.systemGray))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canProcess || isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: Reviewing view

    private var reviewingView: some View {
        VStack(spacing: 0) {
            List {
                ForEach($extractedItems) { $item in
                    ExtractedItemRow(item: $item, lists: lists)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.warmBg)

            Divider()

            let count = extractedItems.filter(\.isIncluded).count
            Button { saveItems() } label: {
                Text(count == 0 ? "No Items Selected" : "Add \(count) Item\(count == 1 ? "" : "s")")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(count > 0 ? Color.appAccent : Color(.systemGray4))
                    .foregroundStyle(count > 0 ? .white : Color(.systemGray))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(count == 0)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: Helpers

    private var canProcess: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func processNote() {
        guard !apiKey.isEmpty else { showingAPIKeySheet = true; return }
        transcriber.stop()
        isProcessing = true
        let note = noteText
        Task {
            do {
                var items = try await AIItemExtractor.extract(from: note, apiKey: apiKey)
                // Pre-populate selectedListID by fuzzy-matching the AI's projectHint
                let snapshot = lists
                let genID = snapshot.first(where: { $0.prefix == "GEN" })?.id
                for i in items.indices {
                    if let hint = items[i].projectHint?.lowercased() {
                        items[i].selectedListID = snapshot.first(where: {
                            $0.name.lowercased().contains(hint) ||
                            $0.prefix.lowercased() == hint
                        })?.id
                    }
                    if items[i].selectedListID == nil { items[i].selectedListID = genID }
                }
                await MainActor.run {
                    extractedItems = items
                    isProcessing = false
                    withAnimation { phase = .reviewing }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func resolveList(hint: String?) -> DashList {
        if let h = hint?.lowercased() {
            if let match = lists.first(where: {
                $0.name.lowercased().contains(h) || $0.prefix.lowercased() == h
            }) { return match }
        }
        if let gen = lists.first(where: { $0.prefix == "GEN" }) { return gen }
        let gen = DashList(name: "General", prefix: "GEN")
        modelContext.insert(gen)
        return gen
    }

    private func saveItems() {
        for extracted in extractedItems where extracted.isIncluded {
            let list = lists.first(where: { $0.id == extracted.selectedListID })
                ?? resolveList(hint: extracted.projectHint)
            let item = DashItem(
                symbol: extracted.symbol,
                categoryCode: list.prefix,
                text: extracted.text,
                sortOrder: list.itemList.count
            )
            item.assignedTo = extracted.assignedTo
            item.waitingFor = extracted.waitingFor
            item.startDate  = extracted.startDate
            item.dueDate    = extracted.dueDate
            item.scheduledDate = extracted.startDate.map {
                Calendar.current.startOfDay(for: $0)
            } ?? Calendar.current.startOfDay(for: Date())
            item.list = list
            modelContext.insert(item)
        }
        dismiss()
    }
}

// MARK: - ExtractedItemRow

private struct ExtractedItemRow: View {
    @Binding var item: ExtractedItem
    let lists: [DashList]

    private var selectedList: DashList? {
        lists.first(where: { $0.id == item.selectedListID })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { item.isIncluded.toggle() } label: {
                Image(systemName: item.isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isIncluded ? Color.appAccent : Color(.systemGray4))
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.symbol.systemImageName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item.symbol.color)
                    TextField("Item text", text: $item.text)
                        .font(.system(.subheadline, design: .monospaced))
                }

                // Project picker
                Menu {
                    ForEach(lists) { list in
                        Button {
                            item.selectedListID = list.id
                        } label: {
                            if list.id == item.selectedListID {
                                Label(list.name, systemImage: "checkmark")
                            } else {
                                Text(list.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .medium))
                        Text(selectedList.map { $0.prefix.isEmpty ? $0.name : $0.prefix } ?? "No Project")
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appAccent.opacity(0.1))
                    .foregroundStyle(Color.appAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    if let start = item.startDate {
                        Label(start.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let due = item.dueDate {
                        Label(due.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isIncluded ? 1 : 0.35)
    }
}

// MARK: - APIKeySheet

struct APIKeySheet: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var isRevealed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if isRevealed {
                                TextField("sk-ant-…", text: $draft)
                            } else {
                                SecureField("sk-ant-…", text: $draft)
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            isRevealed.toggle()
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Tap the eye to reveal the field, then long-press to paste. Stored locally on this device only.")
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apiKey = draft.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { draft = apiKey }
        }
        .presentationDetents([.medium])
    }
}

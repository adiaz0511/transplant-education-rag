import SwiftData
import SwiftUI

struct AskChatView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(GenerationCoordinator.self) private var generationCoordinator

    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @Query(sort: \ChatMessage.createdAt) private var allMessages: [ChatMessage]

    @State private var draft = ""
    @State private var selectedThreadID: UUID?
    @State private var selectedSource: AskSourceSheetItem?
    @State private var renamingThreadID: UUID?
    @State private var renameDraft = ""
    @State private var starterPrompts = AskStarterPrompt.defaultPrompts.shuffled()
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    conversationsSection

                    if currentMessages.isEmpty {
                        emptyState
                    } else {
                        transcript
                    }

                    if isSending {
                        loadingMessage
                            .id(loadingMessageID)
                    }
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 18)
                .padding(.top, 24)
                .padding(.bottom, 12)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(backgroundGradient)
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .navigationTitle("Ask")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                let thread = generationCoordinator.createSessionChatThreadIfNeeded(modelContext: modelContext)
                if selectedThreadID == nil {
                    selectedThreadID = thread.id
                }

                consumePendingDraftIfNeeded()
            }
            .onAppear {
                consumePendingDraftIfNeeded()
                scrollToBottom(using: proxy, animated: false)
            }
            .onChange(of: threads.map(\.id)) { _, ids in
                guard let selectedThreadID else {
                    self.selectedThreadID = ids.first
                    return
                }

                if !ids.contains(selectedThreadID) {
                    self.selectedThreadID = ids.first
                }
            }
            .onChange(of: currentMessages.count) { _, _ in
                scrollToBottom(using: proxy)
            }
            .onChange(of: isSending) { _, _ in
                scrollToBottom(using: proxy)
            }
            .sheet(item: compactSelectedSourceBinding) { source in
                AskSourceDetailView(source: source)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Rename chat", isPresented: renameAlertBinding) {
                TextField("Chat name", text: $renameDraft)

                Button("Save") {
                    commitThreadRename()
                }

                Button("Cancel", role: .cancel) {
                    renamingThreadID = nil
                    renameDraft = ""
                }
            } message: {
                Text("Pick a name you can recognize later.")
            }
        }
    }

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ask anything")
                            .font(.title2.weight(.black))

                        Text("Get quick answers grounded in the heart transplant teaching manual, then keep the conversation going.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        startNewChat()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.black))

                            Text("New chat")
                                .font(.subheadline.weight(.black))
                        }
                    }
                    .buttonStyle(
                        DuolingoBezeledButtonStyle(
                            fillColor: Color(red: 0.17, green: 0.67, blue: 0.64),
                            shadowColor: Color(red: 0.08, green: 0.47, blue: 0.46),
                            cornerRadius: 18
                        )
                    )
                    .disabled(currentMessages.isEmpty)
                }
            }
        }
    }

    private var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved conversations")
                    .font(.headline.weight(.black))

                Spacer(minLength: 0)

                if let currentThread {
                    Text(currentThread.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(threads, id: \.id) { thread in
                        AskThreadCard(
                            thread: thread,
                            isSelected: thread.id == currentThread?.id,
                            onRename: {
                                renameDraft = thread.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                renamingThreadID = thread.id
                            },
                            onDelete: {
                                deleteThread(thread)
                            }
                        ) {
                            selectedThreadID = thread.id
                            draft = ""
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }

    private var transcript: some View {
        VStack(spacing: 16) {
            ForEach(currentMessages, id: \.id) { message in
                AskMessageRow(
                    message: message,
                    onSelectSource: { selectedSource = $0 }
                )
                .id(message.id.uuidString)
            }
        }
    }

    private var loadingMessage: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color(red: 0.10, green: 0.53, blue: 0.52))

                    Text("Thinking...")
                        .font(.headline.weight(.bold))
                }

                Text("Pulling together an answer from the manual.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.trailing, horizontalSizeClass == .regular ? 96 : 36)
    }

    private var emptyState: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Start a conversation")
                    .font(.title3.weight(.black))

                Text("Ask about warning signs, medicines, follow-up appointments, or everyday care after transplant.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(displayedStarterPrompts) { prompt in
                        AskStarterButton(
                            title: prompt.title,
                            action: { draft = prompt.title }
                        )
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 12) {
            if let error = generationCoordinator.activeAskError, !error.isEmpty {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.12))
                    .frame(maxWidth: min(horizontalSizeClass == .regular ? 980 : .infinity, 980), alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: 14) {
                TextField(
                    "Ask about medicines, warning signs, appointments, or daily care",
                    text: $draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color(red: 0.82, green: 0.87, blue: 0.92), lineWidth: 1.5)
                        )
                )
                .focused($isComposerFocused)
                .onSubmit(sendDraft)

                Button(action: sendDraft) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                            .font(.headline.weight(.black))

                        if horizontalSizeClass == .regular {
                            Text("Send")
                                .font(.headline.weight(.black))
                        }
                    }
                }
                .buttonStyle(
                    DuolingoBezeledButtonStyle(
                        fillColor: Color(red: 0.17, green: 0.67, blue: 0.64),
                        shadowColor: Color(red: 0.08, green: 0.47, blue: 0.46)
                    )
                )
                .disabled(sendDisabled)
            }
            .frame(maxWidth: 980, alignment: .center)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.89).opacity(0),
                    Color(red: 0.99, green: 0.97, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var currentThread: ChatThread? {
        if let selectedThreadID,
           let matchingThread = threads.first(where: { $0.id == selectedThreadID }) {
            return matchingThread
        }

        return threads.first
    }

    private var currentMessages: [ChatMessage] {
        guard let thread = currentThread else { return [] }
        return allMessages.filter { $0.threadID == thread.id }
    }

    private var displayedStarterPrompts: [AskStarterPrompt] {
        Array(starterPrompts.prefix(3))
    }

    private var isSending: Bool {
        guard let thread = currentThread else { return false }
        return generationCoordinator.activeAskThreadID == thread.id
    }

    private var sendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || currentThread == nil
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.89),
                Color(red: 0.92, green: 0.98, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var compactSelectedSourceBinding: Binding<AskSourceSheetItem?> {
        Binding(
            get: {
                horizontalSizeClass == .regular ? nil : selectedSource
            },
            set: { newValue in
                selectedSource = newValue
            }
        )
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingThreadID != nil },
            set: { isPresented in
                if !isPresented {
                    renamingThreadID = nil
                    renameDraft = ""
                }
            }
        )
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let thread = currentThread, !text.isEmpty, !isSending else { return }

        draft = ""
        isComposerFocused = false

        Task {
            _ = await generationCoordinator.sendAskMessage(
                text,
                in: thread,
                modelContext: modelContext
            )
        }
    }

    private func consumePendingDraftIfNeeded() {
        guard let pendingDraft = generationCoordinator.pendingAskDraft?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pendingDraft.isEmpty else {
            return
        }

        draft = pendingDraft
        generationCoordinator.pendingAskDraft = nil
        isComposerFocused = true
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let target = isSending ? loadingMessageID : currentMessages.last?.id.uuidString
        guard let target else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    private func commitThreadRename() {
        guard let renamingThreadID,
              let thread = threads.first(where: { $0.id == renamingThreadID }) else {
            self.renamingThreadID = nil
            renameDraft = ""
            return
        }

        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        thread.title = trimmed.isEmpty ? "New chat" : trimmed
        try? modelContext.save()

        self.renamingThreadID = nil
        renameDraft = ""
    }

    private func startNewChat() {
        guard !currentMessages.isEmpty else { return }

        let thread = generationCoordinator.startNewChatSession(modelContext: modelContext)
        selectedThreadID = thread.id
        draft = ""
        starterPrompts.shuffle()
    }

    private func deleteThread(_ thread: ChatThread) {
        let deletedID = thread.id
        let wasSelected = selectedThreadID == deletedID
        let wasCurrentSession = generationCoordinator.currentAskSessionThreadID == deletedID

        modelContext.delete(thread)
        try? modelContext.save()

        if wasCurrentSession {
            generationCoordinator.currentAskSessionThreadID = nil
        }

        if wasSelected {
            if let replacement = threads.first(where: { $0.id != deletedID }) {
                selectedThreadID = replacement.id
            } else {
                let newThread = generationCoordinator.createSessionChatThreadIfNeeded(modelContext: modelContext)
                selectedThreadID = newThread.id
            }
        }
    }

    private let loadingMessageID = "ask-loading-message"
}

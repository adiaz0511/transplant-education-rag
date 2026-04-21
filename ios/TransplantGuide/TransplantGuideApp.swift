//
//  TransplantGuideApp.swift
//  TransplantGuide
//
//  Created by Arturo Diaz on 3/25/26.
//

import SwiftUI
import SwiftData

@main
struct TransplantGuideApp: App {
    @State private var generationCoordinator = GenerationCoordinator()

    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Topic.self,
            Lesson.self,
            Quiz.self,
            StoredQuizQuestion.self,
            ChatThread.self,
            ChatMessage.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(generationCoordinator)
        }
        .modelContainer(sharedModelContainer)
    }
}

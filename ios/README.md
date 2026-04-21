# iOS App

This folder contains the SwiftUI iOS application for the transplant education prototype. The app presents manual topics, generates lessons, supports quiz review, and includes an ask feature for follow-up questions.

## Main Features

- Onboarding flow for selecting and prioritizing lesson topics.
- Lesson library for generated manual-based lessons.
- Quiz flow for testing knowledge on a selected topic.
- Ask interface for direct questions about the manual.
- Local persistence for lessons, quizzes, selected topics, and chat history.

## Backend Configuration

The app reads backend settings from:

- `TransplantGuide/Config/BackendConfig.xcconfig`

The checked-in configuration contains placeholders. For local testing, create a local secrets file:

```text
TransplantGuide/Config/BackendSecrets.local.xcconfig
```

Example:

```text
BACKEND_BASE_URL = "http://127.0.0.1:8000"
BACKEND_APP_ID = mx.devlabs.transplantguide
BACKEND_SHARED_SECRET = REPLACE_WITH_THE_BACKEND_SHARED_SECRET
```

The local secrets file is ignored by Git.

## Running the App

1. Start the backend locally.
2. Open `TransplantGuide.xcodeproj` in Xcode.
3. Select the `TransplantGuide` scheme.
4. Run the app on an iOS simulator.

The backend URL and shared secret must match the backend `.env` file.

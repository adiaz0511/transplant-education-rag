# Pediatric Heart Transplant Education RAG Prototype

This repository contains the source code and supporting artifacts for a retrieval-augmented generation prototype for pediatric heart transplant education. The system uses a Stanford Medicine Children's Health patient education manual as the source document. It includes a backend retrieval and generation service, an iOS application, and a notebook that documents the retriever comparison and backend artifact export.

## Repository Structure

- `backend/`: FastAPI backend for retrieval, prompt construction, request signing, and response generation.
- `ios/`: SwiftUI iOS application for onboarding, lesson generation, quiz review, and direct questions.
- `notebook/`: Google Colab notebook used to prepare the manual corpus, compare retrievers, and export backend artifacts.

## Quick Start for Reviewers

First, clone the repository and enter the source folder:

```bash
git clone https://github.com/adiaz0511/transplant-education-rag.git
cd transplant-education-rag
```

Then run the setup script:

```bash
./setup_project.sh
```

The setup script asks for a Groq API key. It then generates a shared app secret, creates the backend `.env` file, creates the iOS local secrets file, and installs backend dependencies if needed.

After setup, start the backend:

```bash
./run_backend.sh
```

In a second terminal window, open the iOS project:

```bash
./open_ios.sh
```

Finally, run the `TransplantGuide` scheme in Xcode on an iOS simulator.

## Source Manual

The English heart transplant teaching manual is included in the repository because it was the source corpus for the project. The manual was provided as a local patient education document and was used to create the retrieval chunks and indexes.

## Main Workflow

First, the notebook extracts and chunks the manual text. Then, it compares BM25, Contriever, SPECTER, and MedCPT retrieval on representative questions. The final backend uses a hybrid retrieval design with BM25, SPECTER, and MedCPT. Finally, the iOS app calls the backend to generate grounded answers, lessons, and quizzes.

## Folder Guides

Each folder has its own README with more specific instructions:

- [Backend README](backend/README.md)
- [iOS README](ios/README.md)
- [Notebook README](notebook/README.md)

## Local Configuration

The backend and iOS app use local configuration files for secrets. Example configuration files are included where appropriate, but real secrets are not included in this repository.

For local testing, the backend requires a Groq API key and an app shared secret. The iOS app must use the same backend URL, app ID, and shared secret as the backend.

The recommended setup path is `./setup_project.sh`, which creates both local configuration files with matching values.

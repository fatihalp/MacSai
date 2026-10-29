# Contributing

Mac Sai uses Swift 6 and SwiftUI and supports macOS 14 or later.

## Development

1. Create a branch for the change.
2. Keep the change focused and follow the architecture below.
3. Run `swift build` and `swift build -c release`.
4. Run `bash scripts/check-version-sync.sh` and `bash scripts/check-network-surface.sh`.
5. Check the affected screens in the running app, including empty states and cancellation.
6. Open a pull request describing the behavior and verification.

## Architecture

- `Sources/MacClean/Models`: application data, navigation types, and scan contracts.
- `Sources/MacClean/Views`: SwiftUI layout, bindings, and confirmation dialogs.
- `Sources/MacClean/Controllers`: observable state, user actions, and asynchronous task ownership.
- `Sources/MacClean/Services`: result preparation, cleanup orchestration, and macOS integration.
- `Sources/MacClean/Modules`: feature-specific scanning and system clients.
- `Sources/MacClean/Core`: filesystem scanning, deletion, persistence, and monitoring.
- `Sources/MacCleanKit`: shared models, policies, algorithms, localization, and utilities.
- `Sources/MacCleanMenu`: menu bar helper and system statistics.

Views call controllers. Controllers coordinate modules and services. Shared rules belong in
MacCleanKit. Use constructor injection for dependencies that vary; reuse the existing
ScanModule contract and client structs before introducing another abstraction.

Prefer small concrete types and direct control flow. Keep presentation state in views,
long-running operations in controllers, and filesystem policies in the shared library.
Controllers that own UI state use `@MainActor @Observable`.

The package has no automated test targets. Verification uses builds, static checks, and
manual application checks. See [Architecture](docs/ARCHITECTURE.md) for the scan and cleanup flow.

## File operations

Route deletions through SafetyGuard and CleaningEngine. Preserve protected paths, folder
exclusions, explicit selection, cancellation, operation logs, and clean history.
Move items to the Trash unless the selected feature explicitly requires permanent deletion.
Do not use real user files for manual cleanup verification.

## Pull requests

Describe the problem, resulting behavior, and commands used to verify the change.
Include screenshots when changing the UI. Keep VERSION and MCConstants.appVersion in sync
when changing the release version. Follow [Releasing](docs/RELEASING.md) for distribution.

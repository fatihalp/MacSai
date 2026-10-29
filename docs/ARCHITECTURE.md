# Architecture

Mac Sai follows MVC with SwiftUI views and observable controllers. MacCleanKit contains
shared data and policies; MacClean contains application orchestration and macOS integration.

## Responsibilities

| Layer | Responsibility | Examples |
| --- | --- | --- |
| Model | Data, navigation, and operation contracts | ScanResult, ScanFeature, SidebarItem, ScanModule |
| View | Layout, bindings, dialogs, and display formatting | ScanModuleView, ReviewBrowserView |
| Controller | User actions, observable state, task lifecycle | ScanController, SmartScanController, UninstallerController |
| Service | Reusable operations and platform integration | CleanActions, ReviewService, LaunchServicesService |
| Module/Core | Feature scanning and low-level filesystem operations | SystemJunkModule, TargetedScanner, CleaningEngine |

## Scanning

ScanModule supplies scan results. Its default scanOutcome implementation wraps those results;
modules such as TrashBinsModule also report permission failures.

Mail attachments, trash, malware, privacy, and large files share ScanController and ScanModuleView.
ScanFeature selects the module and selection policy. AppState retains these controllers, the
System Junk controller, and the Smart Scan controller so navigation preserves ongoing work.
Specialized screens have their own controllers for feature-specific actions.

ScanController captures an operation generation and checks it before accepting asynchronous
results or progress. Reset cancels existing work and advances that generation. ScanCoordinator
and UI controllers isolate observable changes to the main actor. Scanning does not add delays
to simulate progress; timers remain only where they measure elapsed time or refresh system data.

## Reviewing and cleaning

ReviewDataBuilder prepares grouped data. ReviewService runs that work away from the main actor.
ReviewSelection owns selection counts and sizes. Views display the selection and ask for confirmation.
An empty selection stays empty when review data is rebuilt.

CleanActions maps explicitly selected URLs to trash, permanent deletion, or binary thinning.
CleaningEngine applies SafetyGuard and records each operation. CleanHistoryRecorder stores
restorable Trash operations. Controllers convert CleanResult into CleanSummary and expose
progress, cancellation, and completion to views.

## Extending the application

Add shared data and policies to MacCleanKit. Implement scanning with ScanModule or reuse an
existing system client. Add a controller only when a feature needs a distinct workflow;
use ScanController for standard scan, select, and clean screens. Views should call controller
actions instead of performing discovery, deletion, or process management themselves.

Historical design notes under `docs/superpowers` describe earlier implementations. The current
source tree and this document define the active structure.

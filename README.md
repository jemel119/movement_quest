# Movement Quest

Movement Quest is an offline Flutter app for organizing workout plans,
logging exercise sets, and reviewing training sessions.

**Student:** Jeremy Henry-Atohengbe  
**Level:** Graduate  
**Team:** Solo project

## Project links

- [GitHub repository](https://github.com/jemel119/movement_quest)
- [ClickUp board](https://app.clickup.com/90141785070/v/b/2kydwyze-334)

Demonstration video: pending.

## Features

### Workout plans

- Create, view, edit, and delete plans.
- Record equipment, notes, and an effort preference from 1 to 5.
- Filter plans by equipment.
- Confirm deletion before removing a plan and its training logs.

### Sessions and exercise sets

- Start a labeled session.
- Add exercises with positive whole-number repetitions.
- Edit and delete individual sets.
- Finish a session without inserting duplicate sets.
- Confirm before resetting an unfinished session.
- Restore unfinished sessions that have saved sets.

Each session uses one stable session key. Multiple sets in one completed
session count as one completed session.

A session without saved sets exists only in memory. Leaving the screen
before saving its first set does not create a history record.

### History

- Group sets into completed and unfinished sessions.
- Display session, set, and repetition totals.
- Expand sessions to inspect their sets.
- Edit saved sets and rename sessions.
- Recalculate totals after changes.

Deleting a session's final set removes that session from history.

### Settings

- Save an equipment preference and default effort.
- Apply the default effort to new plans.
- Preserve existing plans' effort values.

No preference and No equipment have different meanings. The first
accepts any equipment; the second prefers workouts without equipment.

### Gear Match

Gear Match recommends a saved plan using deterministic rules:

- Two points for matching the equipment preference.
- One point for differing from the most recently completed session's plan.
- Ascending plan ID to resolve equal scores.

It explains the choice and provides View plan and Not now.
It does not automatically start a workout.

The helper runs locally without a trained model or external inference
service. Its score is not a fitness rating or confidence estimate.

See [AI_FEATURE.md](AI_FEATURE.md) for scoring, evaluation, and limitations.

### Graduate features

- Provider-based shared state.
- Repository interfaces and injected dependencies.
- An implicit summary-card animation.
- Explicit fade and slide animations using an AnimationController.
- Reduced-motion support for those animations.
- Summary computation in a Dart isolate.
- Versioned local JSON summary saving and reading.
- Android daily reminder scheduling, updating, and cancellation.

The isolate runs while the app is active. It is not a service that
continues calculating after the app closes.

Reminders use inexact scheduling. Android may deliver them later than
the selected time. Notification permission is requested when saving a
reminder.

## Local storage

- SQLite stores workout plans and training logs.
- SharedPreferences stores equipment and default-effort preferences.
- A JSON file stores the most recently saved summary snapshot.
- The notification plugin manages the scheduled reminder.

The summary file is named `training_summary.json` and is stored in the
app's documents directory. Saving replaces the previous snapshot.
Reading it does not import or modify workout records.

The app does not require an account, cloud database, or application
backend.

## Development environment

The project was developed using:

- Flutter 3.47.2
- Dart 3.13.2
- VS Code
- Windows PowerShell
- Java 17 compatibility for Android compilation

Dependencies are recorded in `pubspec.yaml` and `pubspec.lock`.

## Setup

Clone the repository and install dependencies:

```powershell
git clone https://github.com/jemel119/movement_quest.git
Set-Location movement_quest
flutter pub get
```

List available devices:

```powershell
flutter devices
```

Run on an Android device or emulator using its listed ID:

```powershell
flutter run -d YOUR_DEVICE_ID
```

## Automated checks

Run static analysis:

```powershell
flutter analyze
```

Run unit and widget tests with coverage:

```powershell
flutter test --coverage
```

The generated coverage data is stored at:

```text
coverage/lcov.info
```

The latest reported coverage test run passed, and the coverage file
was confirmed to exist. No coverage percentage is claimed here.

Tests cover model validation, controllers, session grouping, forms,
history editing, preferences, Gear Match, summaries, file handling,
animations, and reminder state and time calculations.

Many UI tests use fake repositories or services. Those tests do not
verify Android SQLite, notification permissions, or notification delivery.

### Android repository integration tests

Connect an Android device or start an emulator, then run:

```powershell
flutter test integration_test/repository_test.dart -d YOUR_DEVICE_ID
```

These tests use a separate test database. They cover repository CRUD,
session grouping behavior, reset restrictions, cascading deletion,
and database reopening.

Android repository integration testing remains pending.

## Gear Match evaluation

Run the evaluator from the project root:

```powershell
dart run tool/evaluate_gear_match.dart
```

Frozen cases are stored in:

```text
evaluation/gear_match_held_out.json
```

Generated results are stored in:

```text
evaluation/gear_match_results.json
```

Observed results on five synthetic held-out cases:

| Method | Reference matches | Mismatches | Runtime errors |
|---|---:|---:|---:|
| Gear Match | 5/5 | 0/5 | 0 |
| Equipment-only baseline | 3/5 | 2/5 | 0 |

Reference choices were based on the required rules and frozen before
evaluation. These results measure rule compliance on a small synthetic
sample, not user preference or fitness outcomes.

Rerunning the evaluator replaces the results file. If the helper changes
after reviewing the results, a fresh held-out case set is needed.

## Android builds

Build a debug APK:

```powershell
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

The Android debug APK has built successfully.

Build a release APK:

```powershell
flutter build apk --release
```

Expected output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Release build and device verification remain pending. The current
Android configuration uses the Flutter template's debug signing
configuration for release builds.

### Windows build workaround

This project disables Kotlin incremental compilation in
`android/gradle.properties`:

```properties
kotlin.incremental=false
```

## Project management and contribution evidence

Work is tracked on the
[ClickUp board](https://app.clickup.com/90141785070/v/b/2kydwyze-334).

Statuses:

Backlog → Ready → In progress → Review / test → Done

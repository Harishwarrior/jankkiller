# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JankKiller is a Flutter DevTools extension for context-aware screen-flow performance profiling and regression analysis. The project consists of three main components:

1. **Core instrumentation library** (`lib/`) - Flutter package that instruments apps to capture navigation events and frame timing metrics
2. **DevTools extension** (`devtools_extension/`) - Standalone Flutter app that runs inside DevTools to visualize and analyze captured performance data
3. **Example app** (`example/`) - Demonstrates usage of the instrumentation library

## Development Setup

This project uses FVM (Flutter Version Manager) to pin the Flutter SDK version.

**Flutter version**: 3.38.5 (managed via `.fvmrc`)

### Running the project components

```bash
# Run the example app (demonstrates instrumentation)
cd example && flutter run

# Run the DevTools extension (for development/testing)
cd devtools_extension && flutter run

# Run in profile/release mode (recommended for performance testing)
cd example && flutter run --profile
cd example && flutter run --release
```

### Building the DevTools extension

The DevTools extension needs to be built and copied to `extension/devtools/build/`:

```bash
cd devtools_extension
dart run devtools_extensions build_and_copy --source=. --dest=../extension/devtools
```

**Validate the extension setup:**

```bash
dart run devtools_extensions validate --package=.
```

### Testing

```bash
# Run tests for the main package
flutter test

# Run tests for DevTools extension
cd devtools_extension && flutter test

# Run tests for example app
cd example && flutter test
```

### Linting

```bash
flutter analyze
```

## Architecture

### Core Instrumentation Flow (lib/)

**Entry point**: `JankKillerController` - coordinates all instrumentation

```text
JankKillerController
├── PerformanceNavigatorObserver (lib/src/observer/)
│   ├── Listens to route lifecycle (didPush, didPop, didReplace, didRemove)
│   ├── Creates ScreenSession for each route transition
│   └── Emits developer.postEvent() for 'jankkiller:screen_start' and 'jankkiller:screen_end'
│
└── FrameTimingCollector (lib/src/collector/)
    ├── Hooks into SchedulerBinding.addTimingsCallback()
    ├── Buffers frame metrics (batch size: 30 frames)
    └── Emits developer.postEvent() for 'jankkiller:frame_batch'
```

**Key data flow**:

- `PerformanceNavigatorObserver` tracks route transitions and creates `ScreenSession` objects
- `FrameTimingCollector` captures frame timing via Flutter's `SchedulerBinding` and associates frames with the current session
- Both components emit events via `developer.postEvent()` which are picked up by the DevTools extension over VM Service

**Event types**:

- `jankkiller:screen_start` - New route/screen session started
- `jankkiller:screen_end` - Screen session ended
- `jankkiller:frame_batch` - Batch of frame metrics (batched every 30 frames)
- `jankkiller:collector_start` / `jankkiller:collector_stop` - Collector lifecycle events

### DevTools Extension Flow (devtools_extension/)

**Entry point**: `devtools_extension/lib/main.dart`

```text
SessionManager (devtools_extension/lib/src/services/)
├── Connects to VM Service via devtools_extensions package
├── Listens to EventStreams.kExtension for 'jankkiller:*' events
├── Builds ScreenSessionModel objects from events
├── Triggers TelemetryService to pull CPU profiles + Timeline events
└── Runs InsightEngine to detect performance anti-patterns

TelemetryService (devtools_extension/lib/src/services/)
├── Fetches CPU samples via getCpuSamples() for session time range
└── Fetches Timeline events via getVMTimeline()

InsightEngine (devtools_extension/lib/src/services/)
├── Analyzes completed sessions for performance issues
├── Heuristics: excessive jank, high build/raster times, build storms
└── Timeline-based detection: saveLayer, shader compilation, intrinsic layout
```

**UI Structure** (`devtools_extension/lib/src/ui/`):

- `HomeScreen` - Main screen with session list + active session view
- `SessionListView` - Shows all captured sessions
- `SessionDetailView` - Detailed metrics for a single session (charts, insights, timeline)
- `ComparisonView` - Compare multiple sessions for regression analysis
- `FrameChart` (widget) - Visualizes frame timing using fl_chart
- `InsightsPanel` (widget) - Displays performance insights from InsightEngine

### Data Models

**Core models** (`lib/src/models/`):

- `ScreenSession` - Represents a single screen/route lifecycle with associated frame metrics
- `FrameMetric` - Individual frame timing data (build, raster, total duration)

**DevTools models** (`devtools_extension/lib/src/models/`):

- `ScreenSessionModel` - Extension-side session model with additional telemetry (CPU profile, timeline events, insights)
- `PerformanceInsightModel` - Detected performance issue with severity, suggestions, and metadata

### VM Service Integration

The DevTools extension connects to the running app via VM Service:

- Extension events are streamed over `EventStreams.kExtension`
- CPU profiling data is fetched via `getCpuSamples(timeStartMicros, timeExtentMicros)`
- Timeline events are fetched via `getVMTimeline()`

This allows the extension to correlate user-level navigation with low-level profiling data.

## Common Patterns

### Adding a new performance heuristic

1. Add detection logic in `devtools_extension/lib/src/services/insight_engine.dart`
2. Create a new `_detect*` method following the pattern of existing ones
3. Call it from `analyze()`
4. Insights are automatically displayed in the UI via `InsightsPanel`

### Modifying session data schema

1. Update `ScreenSession` model in `lib/src/models/screen_session.dart`
2. Update `ScreenSessionModel` in `devtools_extension/lib/src/models/screen_session_model.dart`
3. Update JSON serialization in both models (`toJson()` / `fromJson()`)
4. Update event emission in `PerformanceNavigatorObserver` if needed
5. Update event handling in `SessionManager._handleScreenStart()` / `_handleScreenEnd()`

### Adding new instrumentation

1. Create collector in `lib/src/collector/`
2. Hook into appropriate Flutter/Dart API (e.g., `SchedulerBinding`, `GestureBinding`, etc.)
3. Emit events via `developer.postEvent('jankkiller:<event_type>', data)`
4. Add event handler in `SessionManager._handleExtensionEvent()`
5. Update UI to display the new data

## DevTools Extension Configuration

The extension is configured via `extension/devtools/config.yaml` with the following required fields:

- **name**: jankkiller - Package name, appears in the extension title bar
- **issueTracker**: <https://github.com/Harishwarrior/jankkiller/issues> - URL for bug reports
- **version**: 0.0.1 - Extension version for tracking updates
- **materialIconCodePoint**: 0xe1b8 - Material icon for the DevTools tab
- **requiresConnection**: true - Requires active Flutter app connection

The extension is enabled in apps via `devtools_options.yaml` at the root.

## Directory Structure

The DevTools extension follows the companion pattern:

```text
jankkiller/
├── lib/                          # Core instrumentation library
├── devtools_extension/           # Extension source code (Flutter web app)
│   └── lib/
└── extension/
    └── devtools/
        ├── config.yaml           # Extension configuration (version controlled)
        └── build/                # Compiled web assets (gitignored, included in pub)
```

## Publishing

Before publishing to pub.dev:

1. **Build the extension:**

   ```bash
   cd devtools_extension
   dart run devtools_extensions build_and_copy --source=. --dest=../extension/devtools
   ```

2. **Validate the extension:**

   ```bash
   dart run devtools_extensions validate --package=.
   ```

3. **Verify required files:**
   - `extension/devtools/config.yaml` must exist and be valid
   - `extension/devtools/build/` must contain compiled web assets
   - `.pubignore` ensures build directory is included despite .gitignore

4. **Publish:**

   ```bash
   flutter pub publish --dry-run  # Preview what will be published
   flutter pub publish            # Publish to pub.dev
   ```

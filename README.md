# JankKiller

A Flutter DevTools extension for context-aware screen-flow performance profiling and regression analysis.

## Overview

JankKiller helps you identify and fix performance issues in your Flutter apps by automatically capturing frame timing metrics segmented by screen sessions. Unlike traditional profilers that show all frames together, JankKiller tracks performance **per screen**, making it easy to:

- Identify which screens have performance problems
- Compare performance across different app flows
- Detect regressions by comparing session baselines
- Get actionable insights with automated performance heuristics

## Features

- **🎯 Screen-Aware Profiling** - Automatically segments frame metrics by navigation routes
- **📊 Real-Time Visualization** - View frame timing charts directly in DevTools
- **🔍 Automated Insights** - Detects excessive jank, high build/raster times, shader compilation, and more
- **📈 Performance Comparison** - Compare sessions to identify regressions
- **🔧 CPU & Timeline Integration** - Pulls CPU profiles and timeline events for deep analysis
- **💾 Export/Import** - Save performance baselines for regression testing
- **🎨 Material Design UI** - Clean, intuitive DevTools integration
- **🖥️ Cross-Platform** - Works on Android, iOS, Web, Windows, macOS, and Linux

## Installation

Add JankKiller to your Flutter app:

```yaml
dependencies:
  jankkiller: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Instrument Your App

Wrap your app with the `JankKillerController` and add the navigator observer:

```dart
import 'package:flutter/material.dart';
import 'package:jankkiller/jankkiller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final JankKillerController _controller = JankKillerController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startCollecting();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [_controller.navigatorObserver],
      home: const HomeScreen(),
    );
  }
}
```

### 2. Enable the DevTools Extension

Add to your app's `pubspec.yaml` (if not already present):

```yaml
# pubspec.yaml - at the root level
```

Create `devtools_options.yaml` in your project root:

```yaml
description: DevTools options for your app
extensions:
  - jankkiller: true
```

### 3. Run Your App & Open DevTools

```bash
# Run in profile mode for accurate performance metrics
flutter run --profile

# DevTools will open automatically, or open it manually:
flutter pub global run devtools
```

### 4. View Performance Data

1. Navigate to the **JankKiller** tab in DevTools
2. Navigate between screens in your app
3. Watch as sessions are captured with frame timing data
4. Click on sessions to view detailed metrics and insights

## Usage

### Basic Setup

```dart
final controller = JankKillerController();

MaterialApp(
  navigatorObservers: [controller.navigatorObserver],
  // ...
)

// Start collecting
controller.startCollecting();
```

### With Callbacks

```dart
final controller = JankKillerController(
  onSessionStart: (session) {
    print('Started: ${session.routeName}');
  },
  onSessionEnd: (session) {
    print('Ended: ${session.routeName}');
    print('Frames: ${session.frameMetrics.length}');
    print('Duration: ${session.durationMs}ms');
  },
  onFrameMetric: (metric) {
    if (metric.isJanky) {
      print('Janky frame: ${metric.totalDurationMs}ms');
    }
  },
);
```

### Using the Wrapper Widget

For automatic lifecycle management:

```dart
MaterialApp(
  home: JankKillerWrapper(
    autoStart: true,
    child: MyHomePage(),
  ),
)
```

### Exporting Data

```dart
// Export all sessions as JSON
final data = controller.exportData(
  appId: 'my_app',
  flutterVersion: '3.24.0',
  device: 'iPhone 14 Pro',
);

// Save to file, send to analytics, etc.
```

## How It Works

### Architecture

JankKiller consists of three components:

1. **Instrumentation Library** (`lib/`) - Flutter package that captures metrics
2. **DevTools Extension** (`devtools_extension/`) - UI for visualization and analysis
3. **Example App** (`example/`) - Demonstrates integration

### Data Flow

```text
Flutter App (with JankKiller)
├── PerformanceNavigatorObserver
│   └── Tracks route lifecycle (push, pop, replace)
│       └── Emits 'jankkiller:screen_start' & 'jankkiller:screen_end'
│
└── FrameTimingCollector
    └── Hooks into SchedulerBinding.addTimingsCallback()
        └── Emits 'jankkiller:frame_batch' (batched every 30 frames)

                    ↓ (VM Service Extension Events)

DevTools Extension (JankKiller Tab)
├── SessionManager
│   ├── Listens to extension events
│   ├── Builds ScreenSession models
│   └── Triggers telemetry collection
│
├── TelemetryService
│   ├── Fetches CPU samples for session timeframe
│   └── Fetches timeline events
│
└── InsightEngine
    └── Analyzes sessions for performance anti-patterns
        ├── Excessive jank (>10% janky frames)
        ├── High build times (>8ms avg)
        ├── High raster times (>8ms avg)
        ├── Build storms (3x avg build time spikes)
        ├── SaveLayer operations
        ├── Shader compilation
        └── Intrinsic layout operations
```

## Performance Insights

JankKiller automatically detects common performance issues:

### Frame-Based Heuristics

- **Excessive Jank** - When >10% of frames exceed the 16.67ms target
- **High Build Times** - Average build time >8ms (leaves no room for raster)
- **High Raster Times** - Average raster time >8ms (GPU bottleneck)
- **Build Storms** - Frames with build times 3x higher than average

### Timeline-Based Heuristics

- **SaveLayer Bleed** - Expensive GPU layer operations from `Opacity`, `ShaderMask`, etc.
- **Shader Jank** - Runtime shader compilation causing frame drops
- **Intrinsic Layout** - `IntrinsicWidth`/`IntrinsicHeight` causing O(N²) layout

Each insight includes:

- Severity level (warning/critical)
- Clear description of the issue
- Actionable suggestions to fix it
- Relevant metrics and counts

## API Reference

### JankKillerController

Main controller for performance instrumentation.

**Constructor:**

```dart
JankKillerController({
  void Function(ScreenSession)? onSessionStart,
  void Function(ScreenSession)? onSessionEnd,
  void Function(FrameMetric)? onFrameMetric,
})
```

**Methods:**

- `void startCollecting()` - Start capturing metrics
- `void stopCollecting()` - Stop capturing metrics
- `void clearSessions()` - Clear all completed sessions
- `void reset()` - Reset to initial state
- `Map<String, dynamic> exportData({...})` - Export sessions as JSON
- `void dispose()` - Clean up resources

**Properties:**

- `bool isActive` - Whether currently collecting
- `ScreenSession? currentSession` - Currently active session
- `List<ScreenSession> completedSessions` - All completed sessions
- `int frameCount` - Total frames captured

### ScreenSession

Represents a single screen/route lifecycle with frame metrics.

**Properties:**

- `String sessionId` - Unique session identifier
- `String routeName` - Route name or auto-generated identifier
- `int startTimeMicros` - Session start timestamp
- `int? endTimeMicros` - Session end timestamp
- `bool isPopup` - Whether route is a popup (dialog, bottom sheet, etc.)
- `String? previousRoute` - Previous route name
- `List<FrameMetric> frameMetrics` - All captured frames
- `double? durationMs` - Session duration in milliseconds
- `double avgBuildMs` - Average build time
- `double avgRasterMs` - Average raster time
- `int jankyFrameCount` - Count of janky frames
- `double jankPercentage` - Percentage of janky frames

### FrameMetric

Individual frame timing data.

**Properties:**

- `int timestampMicros` - Frame timestamp
- `int buildDurationMicros` - Build phase duration
- `int rasterDurationMicros` - Raster phase duration
- `int totalDurationMicros` - Total frame duration
- `int frameNumber` - Sequential frame number
- `bool isJanky` - Whether frame exceeded 16.67ms budget
- `double buildDurationMs` - Build duration in milliseconds
- `double rasterDurationMs` - Raster duration in milliseconds
- `double totalDurationMs` - Total duration in milliseconds

## Development

### Prerequisites

- Flutter SDK ≥3.10.0
- Dart SDK ≥3.0.0
- FVM (optional, but recommended)

### Setup

```bash
# Clone the repository
git clone https://github.com/Harishwarrior/jankkiller.git
cd jankkiller

# Use FVM (optional)
fvm use 3.38.5

# Get dependencies
flutter pub get
cd devtools_extension && flutter pub get
cd ../example && flutter pub get
```

### Running the Example

The example app supports all platforms: Android, iOS, Web, Windows, macOS, and Linux.

```bash
cd example

# Mobile
flutter run --profile                    # Auto-select connected device
flutter run -d android --profile         # Android
flutter run -d ios --profile             # iOS

# Desktop
flutter run -d macos --profile           # macOS
flutter run -d windows --profile         # Windows
flutter run -d linux --profile           # Linux

# Web
flutter run -d chrome --profile          # Chrome browser
```

**Note:** Run in **profile mode** for accurate performance metrics. Debug mode has additional overhead that skews results.

### Building the DevTools Extension

```bash
cd devtools_extension
dart run devtools_extensions build_and_copy --source=. --dest=../extension/devtools
```

### Validating

```bash
dart run devtools_extensions validate --package=.
```

### Testing

```bash
# Run tests for main package
flutter test

# Run tests for DevTools extension
cd devtools_extension && flutter test

# Run tests for example
cd example && flutter test
```

### Linting

```bash
flutter analyze
```

## Publishing

Before publishing to pub.dev:

1. **Build the extension:**

   ```bash
   cd devtools_extension
   dart run devtools_extensions build_and_copy --source=. --dest=../extension/devtools
   ```

2. **Validate:**

   ```bash
   dart run devtools_extensions validate --package=.
   ```

3. **Verify files:**
   - `extension/devtools/config.yaml` exists and is valid
   - `extension/devtools/build/` contains compiled assets
   - `.pubignore` includes the build directory

4. **Publish:**

   ```bash
   flutter pub publish --dry-run
   flutter pub publish
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Troubleshooting

### DevTools extension not showing up

1. Ensure `devtools_options.yaml` exists in your project root
2. Restart your Flutter app
3. Close and reopen DevTools

### No sessions appearing

1. Verify you're running in **profile** or **release** mode (not debug)
2. Check that `navigatorObservers` includes the controller's observer
3. Ensure `startCollecting()` was called after `WidgetsBinding.ensureInitialized()`

### Frame data not captured

1. Make sure you called `startCollecting()` before navigation
2. Verify the app is actually rendering frames (navigate between screens)
3. Check console for any error messages

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with [devtools_extensions](https://pub.dev/packages/devtools_extensions)
- Visualization powered by [fl_chart](https://pub.dev/packages/fl_chart)
- Inspired by Flutter DevTools Performance view

## Support

- [Issue Tracker](https://github.com/Harishwarrior/jankkiller/issues)
- [Documentation](https://github.com/Harishwarrior/jankkiller)
- [Example App](https://github.com/Harishwarrior/jankkiller/tree/main/example)

---

Made with ❤️ for the Flutter community

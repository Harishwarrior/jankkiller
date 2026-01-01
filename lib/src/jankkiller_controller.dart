import 'package:flutter/widgets.dart';

import 'collector/frame_timing_collector.dart';
import 'models/frame_metric.dart';
import 'models/screen_session.dart';
import 'observer/performance_navigator_observer.dart';

/// Main controller for jankkiller performance instrumentation.
///
/// This controller coordinates the [PerformanceNavigatorObserver] and
/// [FrameTimingCollector] to provide unified screen-flow performance metrics.
///
/// ## Usage
/// ```dart
/// final controller = JankKillerController();
///
/// MaterialApp(
///   navigatorObservers: [controller.navigatorObserver],
///   // ...
/// )
///
/// // Start collecting when app is ready
/// controller.startCollecting();
/// ```
class JankKillerController {
  /// The navigator observer for capturing screen transitions.
  late final PerformanceNavigatorObserver navigatorObserver;

  /// The frame timing collector for capturing render performance.
  late final FrameTimingCollector frameTimingCollector;

  /// Whether the controller is currently active.
  bool _isActive = false;

  /// Callback when a new session starts.
  final void Function(ScreenSession session)? onSessionStart;

  /// Callback when a session ends.
  final void Function(ScreenSession session)? onSessionEnd;

  /// Callback for each frame metric.
  final void Function(FrameMetric metric)? onFrameMetric;

  JankKillerController({
    this.onSessionStart,
    this.onSessionEnd,
    this.onFrameMetric,
  }) {
    navigatorObserver = PerformanceNavigatorObserver(
      onSessionStart: (session) {
        onSessionStart?.call(session);
      },
      onSessionEnd: (session) {
        onSessionEnd?.call(session);
      },
    );

    frameTimingCollector = FrameTimingCollector(
      onFrameMetric: (metric) {
        // Add frame metric to the current session
        navigatorObserver.addFrameMetricToCurrentSession(
          metric.timestampMicros,
          metric.buildDurationMicros,
          metric.rasterDurationMicros,
          metric.totalDurationMicros,
          metric.frameNumber,
        );
        onFrameMetric?.call(metric);
      },
    );
  }

  /// Returns whether the controller is currently active.
  bool get isActive => _isActive;

  /// Returns the currently active session.
  ScreenSession? get currentSession => navigatorObserver.currentSession;

  /// Returns all completed sessions.
  List<ScreenSession> get completedSessions =>
      navigatorObserver.completedSessions;

  /// Returns the total frame count.
  int get frameCount => frameTimingCollector.frameCount;

  /// Starts performance collection.
  ///
  /// This should be called after the app's widget binding is initialized,
  /// typically in the `initState` of your root widget or after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  void startCollecting() {
    if (_isActive) return;
    frameTimingCollector.start();
    _isActive = true;
  }

  /// Stops performance collection.
  void stopCollecting() {
    if (!_isActive) return;
    frameTimingCollector.stop();
    _isActive = false;
  }

  /// Clears all completed sessions.
  void clearSessions() {
    navigatorObserver.clearCompletedSessions();
  }

  /// Resets the controller to its initial state.
  void reset() {
    stopCollecting();
    clearSessions();
    frameTimingCollector.reset();
  }

  /// Exports all completed sessions as JSON.
  ///
  /// Returns a map containing metadata and session data suitable for
  /// regression analysis.
  Map<String, dynamic> exportData({
    String? appId,
    String? flutterVersion,
    String? device,
  }) {
    return {
      'meta': {
        'schemaVersion': '1.0',
        'appId': appId ?? 'unknown',
        'flutterVersion': flutterVersion ?? 'unknown',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'device': device ?? 'unknown',
        'totalFrames': frameCount,
      },
      'sessions': navigatorObserver.exportSessions(),
    };
  }

  /// Disposes of the controller and releases resources.
  void dispose() {
    stopCollecting();
  }
}

/// Widget wrapper that automatically manages [JankKillerController] lifecycle.
///
/// Wrap your app or a subtree to automatically start/stop collection.
class JankKillerWrapper extends StatefulWidget {
  /// The child widget to wrap.
  final Widget child;

  /// The controller to use. If not provided, a new one is created.
  final JankKillerController? controller;

  /// Whether to auto-start collection when the widget is mounted.
  final bool autoStart;

  const JankKillerWrapper({
    super.key,
    required this.child,
    this.controller,
    this.autoStart = true,
  });

  @override
  State<JankKillerWrapper> createState() => _JankKillerWrapperState();
}

class _JankKillerWrapperState extends State<JankKillerWrapper> {
  late final JankKillerController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = JankKillerController();
      _ownsController = true;
    }

    if (widget.autoStart) {
      // Use post frame callback to ensure binding is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.startCollecting();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

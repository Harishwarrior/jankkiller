import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import '../models/frame_metric.dart';
import '../models/screen_session.dart';

/// A NavigatorObserver that captures screen transitions and emits semantic
/// markers via the Dart developer timeline.
///
/// This observer intercepts route lifecycle events (push, pop, replace, remove)
/// and broadcasts them to the DevTools extension via [developer.postEvent].
///
/// ## Usage
/// ```dart
/// MaterialApp(
///   navigatorObservers: [PerformanceNavigatorObserver()],
///   // ...
/// )
/// ```
class PerformanceNavigatorObserver extends NavigatorObserver {
  /// The event kind prefix used for all navigation events.
  static const String eventPrefix = 'jankkiller';

  /// Callback invoked when a new session starts.
  final void Function(ScreenSession session)? onSessionStart;

  /// Callback invoked when a session ends.
  final void Function(ScreenSession session)? onSessionEnd;

  /// Currently active sessions (stack-based for nested navigation).
  final List<ScreenSession> _activeSessions = [];

  /// All completed sessions.
  final List<ScreenSession> _completedSessions = [];

  PerformanceNavigatorObserver({
    this.onSessionStart,
    this.onSessionEnd,
  });

  /// Returns the currently active session (top of the stack).
  ScreenSession? get currentSession =>
      _activeSessions.isNotEmpty ? _activeSessions.last : null;

  /// Returns all completed sessions.
  List<ScreenSession> get completedSessions =>
      List.unmodifiable(_completedSessions);

  /// Returns the active session stack.
  List<ScreenSession> get activeSessions => List.unmodifiable(_activeSessions);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _startSession(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _endSession(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      _endSession(oldRoute);
    }
    if (newRoute != null) {
      _startSession(newRoute, null);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _endSession(route);
  }

  /// Starts a new screen session for the given route.
  void _startSession(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final now = developer.Timeline.now;
    final routeName = _extractRouteName(route);
    final previousRouteName =
        previousRoute != null ? _extractRouteName(previousRoute) : null;
    final isPopup = route is PopupRoute;

    final session = ScreenSession(
      routeName: routeName,
      startTimeMicros: now,
      isPopup: isPopup,
      previousRoute: previousRouteName,
    );

    _activeSessions.add(session);

    // Emit the screen start event via postEvent
    developer.postEvent(
      '$eventPrefix:screen_start',
      {
        'sessionId': session.sessionId,
        'route': routeName,
        'timestamp': now,
        'isPopup': isPopup,
        'previousRoute': previousRouteName,
      },
    );

    onSessionStart?.call(session);
  }

  /// Ends the session for the given route.
  void _endSession(Route<dynamic> route) {
    final routeName = _extractRouteName(route);
    final now = developer.Timeline.now;

    // Find and remove the matching session from the stack
    final sessionIndex = _activeSessions.lastIndexWhere(
      (s) => s.routeName == routeName && s.endTimeMicros == null,
    );

    if (sessionIndex == -1) {
      // Session not found, might have been already closed
      return;
    }

    final session = _activeSessions.removeAt(sessionIndex);
    session.end(now);
    _completedSessions.add(session);

    // Emit the screen end event via postEvent
    developer.postEvent(
      '$eventPrefix:screen_end',
      {
        'sessionId': session.sessionId,
        'route': routeName,
        'timestamp': now,
        'durationMicros': session.durationMicros,
        'frameCount': session.frameMetrics.length,
      },
    );

    onSessionEnd?.call(session);
  }

  /// Extracts the route name from a route.
  /// Falls back to the runtime type if no name is specified.
  String _extractRouteName(Route<dynamic> route) {
    final settings = route.settings;

    // Prefer the explicit route name if available
    if (settings.name != null && settings.name!.isNotEmpty) {
      return settings.name!;
    }

    // Try to get a meaningful name from the route type or arguments
    final arguments = settings.arguments;
    if (arguments is Map && arguments.containsKey('routeName')) {
      return arguments['routeName'] as String;
    }

    // Fallback to runtime type with a hash for uniqueness
    return '${route.runtimeType}#${route.hashCode.toRadixString(16)}';
  }

  /// Adds a frame metric to the currently active session.
  void addFrameMetricToCurrentSession(
    int timestampMicros,
    int buildDurationMicros,
    int rasterDurationMicros,
    int totalDurationMicros,
    int frameNumber,
  ) {
    final session = currentSession;
    if (session == null) return;

    // Only add if the frame timestamp falls within this session
    if (timestampMicros >= session.startTimeMicros) {
      session.addFrameMetric(
        FrameMetric(
          timestampMicros: timestampMicros,
          buildDurationMicros: buildDurationMicros,
          rasterDurationMicros: rasterDurationMicros,
          totalDurationMicros: totalDurationMicros,
          frameNumber: frameNumber,
        ),
      );
    }
  }

  /// Clears all completed sessions.
  void clearCompletedSessions() {
    _completedSessions.clear();
  }

  /// Exports all completed sessions as JSON.
  List<Map<String, dynamic>> exportSessions() {
    return _completedSessions.map((s) => s.toJson()).toList();
  }
}

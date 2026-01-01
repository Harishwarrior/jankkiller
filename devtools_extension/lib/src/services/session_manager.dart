import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../models/screen_session_model.dart';
import 'insight_engine.dart';
import 'telemetry_service.dart';

/// Manages screen sessions by listening to VM Service events.
class SessionManager extends ChangeNotifier {
  final List<ScreenSessionModel> _sessions = [];
  ScreenSessionModel? _activeSession;
  StreamSubscription<Event>? _extensionSubscription;
  bool _isInitialized = false;

  /// Throttle timer to limit notifyListeners calls during frame batches.
  Timer? _notifyThrottleTimer;
  bool _pendingNotification = false;
  static const _throttleDuration = Duration(milliseconds: 100);

  /// All captured sessions (completed + active).
  List<ScreenSessionModel> get sessions => List.unmodifiable(_sessions);

  /// Currently active session.
  ScreenSessionModel? get activeSession => _activeSession;

  /// Whether the manager is initialized and connected.
  bool get isInitialized => _isInitialized;

  /// Initialize the session manager and connect to VM Service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Wait for connection to be established
      if (serviceManager.service == null) {
        await serviceManager.onServiceAvailable;
      }

      final service = serviceManager.service;
      if (service == null) {
        throw StateError('VM Service not available after waiting');
      }

      // Listen for extension events from the client app
      _extensionSubscription =
          service.onExtensionEvent.listen(_handleExtensionEvent);

      // Enable the Extension stream
      await service.streamListen(EventStreams.kExtension);

      // Initialize Telemetry Service
      await TelemetryService.instance.initialize();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Handle incoming extension events from the client app.
  void _handleExtensionEvent(Event event) {
    final extensionKind = event.extensionKind;
    final extensionData = event.extensionData?.data;

    if (extensionData == null) return;

    switch (extensionKind) {
      case 'jankkiller:screen_start':
        _handleScreenStart(extensionData);
        break;
      case 'jankkiller:screen_end':
        _handleScreenEnd(extensionData);
        break;
      case 'jankkiller:frame_batch':
        _handleFrameBatch(extensionData);
        break;
      case 'jankkiller:collector_start':
      case 'jankkiller:collector_stop':
        // Log these events but don't process them
        break;
    }
  }

  /// Handle screen start event.
  void _handleScreenStart(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String;

    // Check if a session with this ID already exists to prevent duplicates
    final existingSessionIndex = _sessions.indexWhere(
      (s) => s.sessionId == sessionId,
    );

    if (existingSessionIndex != -1) {
      // Session already exists, just update active session reference
      _activeSession = _sessions[existingSessionIndex];
      notifyListeners();
      return;
    }

    final session = ScreenSessionModel(
      sessionId: sessionId,
      routeName: data['route'] as String,
      startTimeMicros: data['timestamp'] as int,
      isPopup: data['isPopup'] as bool? ?? false,
      previousRoute: data['previousRoute'] as String?,
    );

    _sessions.add(session);
    _activeSession = session;
    notifyListeners();
  }

  /// Handle screen end event.
  void _handleScreenEnd(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String;
    final endTimestamp = data['timestamp'] as int;

    final session = _sessions.firstWhere(
      (s) => s.sessionId == sessionId,
      orElse: () => throw StateError('Session not found: $sessionId'),
    );

    session.end(endTimestamp);

    // Pull telemetry for the completed session
    _collectTelemetryForSession(session);

    // Update active session to the previous one if available
    final activeSessions = _sessions.where((s) => s.isActive).toList();
    _activeSession = activeSessions.isNotEmpty ? activeSessions.last : null;

    notifyListeners();
  }

  /// Collects CPU profile and timeline events for a completed session.
  Future<void> _collectTelemetryForSession(ScreenSessionModel session) async {
    final startTime = session.startTimeMicros;
    final duration = session.durationMicros;
    if (duration == null) return;

    // 1. Fetch CPU Samples
    final cpuSamples = await TelemetryService.instance.getCpuSamples(
      timeStartMicros: startTime,
      timeExtentMicros: duration,
    );
    if (cpuSamples != null) {
      session.cpuProfile = cpuSamples.json;
    }

    // 2. Fetch Timeline Events
    // Note: Streaming is better for real-time, but here we pull historical for the session range
    final timeline = await TelemetryService.instance.getVMTimeline();
    if (timeline != null) {
      session.timelineEvents =
          timeline.traceEvents?.map((e) => e.json!).toList() ?? [];
    }

    // 3. Run Insight Engine
    session.insights = InsightEngine.instance.analyze(session);

    notifyListeners();
  }

  /// Handle frame batch event with throttled notifications.
  void _handleFrameBatch(Map<String, dynamic> data) {
    final frames = data['frames'] as List?;
    if (frames == null || _activeSession == null) return;

    for (final frame in frames) {
      final frameData = Map<String, dynamic>.from(frame as Map);
      final metric = FrameMetricModel.fromJson(frameData);
      _activeSession!.addFrameMetric(metric);
    }

    // Use throttled notification to avoid excessive UI rebuilds
    _scheduleNotification();
  }

  /// Schedules a throttled notification to avoid excessive UI rebuilds.
  void _scheduleNotification() {
    if (_notifyThrottleTimer?.isActive == true) {
      _pendingNotification = true;
      return;
    }
    notifyListeners();
    _notifyThrottleTimer = Timer(_throttleDuration, () {
      if (_pendingNotification) {
        _pendingNotification = false;
        notifyListeners();
      }
    });
  }

  /// Refresh session data (re-request from client).
  void refresh() {
    notifyListeners();
  }

  /// Clear all sessions.
  void clearSessions() {
    _sessions.clear();
    _activeSession = null;
    notifyListeners();
  }

  /// Export all sessions as JSON.
  Map<String, dynamic> exportSessions({
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
      },
      'sessions': _sessions.map((s) => s.toJson()).toList(),
    };
  }

  /// Import sessions from JSON baseline.
  List<ScreenSessionModel> importSessions(Map<String, dynamic> data) {
    final sessionsData = data['sessions'] as List?;
    if (sessionsData == null) return [];

    return sessionsData
        .map((s) => ScreenSessionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  @override
  void dispose() {
    _notifyThrottleTimer?.cancel();
    _extensionSubscription?.cancel();
    super.dispose();
  }
}

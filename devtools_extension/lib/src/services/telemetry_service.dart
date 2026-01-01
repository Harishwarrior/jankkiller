import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

/// Service for interacting with VM Service RPCs and streams.
class TelemetryService {
  TelemetryService._();
  static final instance = TelemetryService._();

  StreamSubscription? _timelineSubscription;
  final _timelineController = StreamController<Event>.broadcast();

  Stream<Event> get onTimelineEvent => _timelineController.stream;

  /// Initializes the telemetry service by subscribing to necessary streams.
  Future<void> initialize() async {
    final service = serviceManager.service;
    if (service == null) return;

    try {
      // Subscribe to Timeline events
      _timelineSubscription = service.onTimelineEvent
          .listen((event) => _timelineController.add(event));
      await service.streamListen(EventStreams.kTimeline);
    } catch (e) {
      debugPrint('Error initializing TelemetryService: $e');
    }
  }

  /// Fetches CPU samples for the main isolate within a time range.
  Future<CpuSamples?> getCpuSamples({
    required int timeStartMicros,
    required int timeExtentMicros,
  }) async {
    final service = serviceManager.service;
    final isolateId = serviceManager.isolateManager.selectedIsolate.value?.id;

    if (service == null || isolateId == null) return null;

    try {
      return await service.getCpuSamples(
        isolateId,
        timeStartMicros,
        timeExtentMicros,
      );
    } catch (e) {
      debugPrint('Error fetching CPU samples: $e');
      return null;
    }
  }

  /// Fetches the full timeline for a given period.
  Future<Timeline?> getVMTimeline({
    int? timeStartMicros,
    int? timeExtentMicros,
  }) async {
    final service = serviceManager.service;
    if (service == null) return null;

    try {
      return await service.getVMTimeline();
    } catch (e) {
      debugPrint('Error fetching VM timeline: $e');
      return null;
    }
  }

  void dispose() {
    _timelineSubscription?.cancel();
    _timelineController.close();
  }
}

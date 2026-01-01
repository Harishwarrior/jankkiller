import 'dart:developer' as developer;

import 'package:flutter/scheduler.dart';

import '../models/frame_metric.dart';

/// Collects frame timing metrics from Flutter's rendering pipeline.
///
/// This collector hooks into the [SchedulerBinding.addTimingsCallback] to
/// receive [FrameTiming] data for every rendered frame. Metrics are buffered
/// and periodically sent to the DevTools extension via [developer.postEvent].
class FrameTimingCollector {
  /// The event kind for frame timing batches.
  static const String eventKind = 'jankkiller:frame_batch';

  /// Maximum frames to buffer before sending a batch.
  static const int batchSize = 30;

  /// Callback for frame timing data (internal use).
  TimingsCallback? _callback;

  /// Buffered frame metrics waiting to be sent.
  final List<FrameMetric> _buffer = [];

  /// Frame counter for sequential numbering.
  int _frameCounter = 0;

  /// Whether the collector is currently active.
  bool _isCollecting = false;

  /// Optional callback for each frame metric.
  final void Function(FrameMetric metric)? onFrameMetric;

  /// Optional callback when a batch is sent.
  final void Function(List<FrameMetric> batch)? onBatchSent;

  FrameTimingCollector({this.onFrameMetric, this.onBatchSent});

  /// Returns whether the collector is currently active.
  bool get isCollecting => _isCollecting;

  /// Returns the current frame count.
  int get frameCount => _frameCounter;

  /// Starts collecting frame timing data.
  void start() {
    if (_isCollecting) return;

    _callback = _handleTimings;
    SchedulerBinding.instance.addTimingsCallback(_callback!);
    _isCollecting = true;

    developer.postEvent('jankkiller:collector_start', {
      'timestamp': developer.Timeline.now,
    });
  }

  /// Stops collecting frame timing data.
  void stop() {
    if (!_isCollecting) return;

    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
      _callback = null;
    }
    _isCollecting = false;

    // Flush any remaining buffered frames
    _flushBuffer();

    developer.postEvent('jankkiller:collector_stop', {
      'timestamp': developer.Timeline.now,
      'totalFrames': _frameCounter,
    });
  }

  /// Resets the collector state.
  void reset() {
    stop();
    _buffer.clear();
    _frameCounter = 0;
  }

  /// Handles incoming frame timing data from the scheduler.
  void _handleTimings(List<FrameTiming> timings) {
    final now = developer.Timeline.now;

    for (final timing in timings) {
      _frameCounter++;

      final metric = FrameMetric(
        timestampMicros: now,
        buildDurationMicros: timing.buildDuration.inMicroseconds,
        rasterDurationMicros: timing.rasterDuration.inMicroseconds,
        totalDurationMicros: timing.totalSpan.inMicroseconds,
        frameNumber: _frameCounter,
      );

      _buffer.add(metric);
      onFrameMetric?.call(metric);

      // Flush buffer if we've reached the batch size
      if (_buffer.length >= batchSize) {
        _flushBuffer();
      }
    }
  }

  /// Flushes the buffer by sending accumulated metrics to DevTools.
  void _flushBuffer() {
    if (_buffer.isEmpty) return;

    final batch = List<FrameMetric>.from(_buffer);
    _buffer.clear();

    // Send the batch via postEvent
    developer.postEvent(eventKind, {
      'timestamp': developer.Timeline.now,
      'frameCount': batch.length,
      'frames': batch.map((m) => m.toJson()).toList(),
    });

    onBatchSent?.call(batch);
  }

  /// Forces a flush of the current buffer.
  void flush() {
    _flushBuffer();
  }
}

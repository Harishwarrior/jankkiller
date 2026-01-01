/// Represents timing metrics for a single rendered frame.
///
/// Maps to Flutter's FrameTiming API, capturing build and raster durations.
class FrameMetric {
  /// Monotonic timestamp (microseconds) when this frame was captured.
  final int timestampMicros;

  /// Time spent in the UI thread building widgets (microseconds).
  final int buildDurationMicros;

  /// Time spent in the raster thread rendering (microseconds).
  final int rasterDurationMicros;

  /// Total frame time from build start to raster end (microseconds).
  final int totalDurationMicros;

  /// Frame number (sequential counter).
  final int frameNumber;

  /// Whether this frame exceeded the target frame time (16.67ms for 60Hz).
  bool get isJanky => totalDurationMicros > 16670;

  /// Build duration in milliseconds.
  double get buildDurationMs => buildDurationMicros / 1000.0;

  /// Raster duration in milliseconds.
  double get rasterDurationMs => rasterDurationMicros / 1000.0;

  /// Total duration in milliseconds.
  double get totalDurationMs => totalDurationMicros / 1000.0;

  const FrameMetric({
    required this.timestampMicros,
    required this.buildDurationMicros,
    required this.rasterDurationMicros,
    required this.totalDurationMicros,
    required this.frameNumber,
  });

  /// Creates a FrameMetric from Flutter's FrameTiming object data.
  factory FrameMetric.fromFrameTiming({
    required int timestampMicros,
    required int buildStartMicros,
    required int buildFinishMicros,
    required int rasterStartMicros,
    required int rasterFinishMicros,
    required int frameNumber,
  }) {
    return FrameMetric(
      timestampMicros: timestampMicros,
      buildDurationMicros: buildFinishMicros - buildStartMicros,
      rasterDurationMicros: rasterFinishMicros - rasterStartMicros,
      totalDurationMicros: rasterFinishMicros - buildStartMicros,
      frameNumber: frameNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestampMicros': timestampMicros,
      'buildDurationMicros': buildDurationMicros,
      'rasterDurationMicros': rasterDurationMicros,
      'totalDurationMicros': totalDurationMicros,
      'frameNumber': frameNumber,
    };
  }

  factory FrameMetric.fromJson(Map<String, dynamic> json) {
    return FrameMetric(
      timestampMicros: json['timestampMicros'] as int,
      buildDurationMicros: json['buildDurationMicros'] as int,
      rasterDurationMicros: json['rasterDurationMicros'] as int,
      totalDurationMicros: json['totalDurationMicros'] as int,
      frameNumber: json['frameNumber'] as int,
    );
  }

  @override
  String toString() {
    return 'FrameMetric(frame: $frameNumber, build: ${buildDurationMs.toStringAsFixed(2)}ms, '
        'raster: ${rasterDurationMs.toStringAsFixed(2)}ms, total: ${totalDurationMs.toStringAsFixed(2)}ms)';
  }
}

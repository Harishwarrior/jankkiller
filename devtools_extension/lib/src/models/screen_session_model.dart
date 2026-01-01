/// Model representing a screen session in the extension.
///
/// This mirrors the client-side ScreenSession but is used for display
/// and analysis in the DevTools extension.
class ScreenSessionModel {
  final String sessionId;
  final String routeName;
  final int startTimeMicros;
  int? endTimeMicros;
  final bool isPopup;
  final String? previousRoute;
  final List<FrameMetricModel> frameMetrics;
  List<Map<String, dynamic>> timelineEvents;
  List<PerformanceInsightModel> insights;
  Map<String, dynamic>? cpuProfile;
  Map<String, dynamic>? memoryStats;

  ScreenSessionModel({
    required this.sessionId,
    required this.routeName,
    required this.startTimeMicros,
    this.endTimeMicros,
    this.isPopup = false,
    this.previousRoute,
    List<FrameMetricModel>? frameMetrics,
    List<Map<String, dynamic>>? timelineEvents,
    List<PerformanceInsightModel>? insights,
    this.cpuProfile,
    this.memoryStats,
  })  : frameMetrics = frameMetrics ?? [],
        timelineEvents = timelineEvents ?? [],
        insights = insights ?? [];

  /// Duration in microseconds, null if session is still active.
  int? get durationMicros {
    if (endTimeMicros == null) return null;
    return endTimeMicros! - startTimeMicros;
  }

  /// Duration in milliseconds.
  double? get durationMs {
    final micros = durationMicros;
    if (micros == null) return null;
    return micros / 1000.0;
  }

  /// Whether this session is currently active.
  bool get isActive => endTimeMicros == null;

  /// Average build duration in milliseconds.
  double get avgBuildMs {
    if (frameMetrics.isEmpty) return 0;
    return frameMetrics.map((f) => f.buildDurationMs).reduce((a, b) => a + b) /
        frameMetrics.length;
  }

  /// Average raster duration in milliseconds.
  double get avgRasterMs {
    if (frameMetrics.isEmpty) return 0;
    return frameMetrics.map((f) => f.rasterDurationMs).reduce((a, b) => a + b) /
        frameMetrics.length;
  }

  /// Number of janky frames (>16.67ms).
  int get jankyFrameCount {
    return frameMetrics.where((f) => f.totalDurationMs > 16.67).length;
  }

  /// Jank percentage (0-100).
  double get jankPercentage {
    if (frameMetrics.isEmpty) return 0;
    return (jankyFrameCount / frameMetrics.length) * 100;
  }

  /// Ends this session.
  void end(int endTimeMicros) {
    this.endTimeMicros = endTimeMicros;
  }

  /// Adds a frame metric.
  void addFrameMetric(FrameMetricModel metric) {
    frameMetrics.add(metric);
  }

  /// Creates from JSON data.
  factory ScreenSessionModel.fromJson(Map<String, dynamic> json) {
    return ScreenSessionModel(
      sessionId: json['sessionId'] as String,
      routeName: json['routeName'] as String? ?? json['route'] as String,
      startTimeMicros:
          json['startTimeMicros'] as int? ?? json['timestamp'] as int,
      endTimeMicros: json['endTimeMicros'] as int?,
      isPopup: json['isPopup'] as bool? ?? false,
      previousRoute: json['previousRoute'] as String?,
      frameMetrics: (json['frameMetrics'] as List?)
              ?.map((m) => FrameMetricModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      timelineEvents: (json['timelineEvents'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      insights: (json['insights'] as List?)
              ?.map((i) =>
                  PerformanceInsightModel.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'routeName': routeName,
      'startTimeMicros': startTimeMicros,
      'endTimeMicros': endTimeMicros,
      'isPopup': isPopup,
      'previousRoute': previousRoute,
      'frameMetrics': frameMetrics.map((m) => m.toJson()).toList(),
      'timelineEvents': timelineEvents,
      'insights': insights.map((i) => i.toJson()).toList(),
    };
  }
}

/// Model for frame timing metrics.
class FrameMetricModel {
  final int timestampMicros;
  final int buildDurationMicros;
  final int rasterDurationMicros;
  final int totalDurationMicros;
  final int frameNumber;

  const FrameMetricModel({
    required this.timestampMicros,
    required this.buildDurationMicros,
    required this.rasterDurationMicros,
    required this.totalDurationMicros,
    required this.frameNumber,
  });

  double get buildDurationMs => buildDurationMicros / 1000.0;
  double get rasterDurationMs => rasterDurationMicros / 1000.0;
  double get totalDurationMs => totalDurationMicros / 1000.0;
  bool get isJanky => totalDurationMs > 16.67;

  factory FrameMetricModel.fromJson(Map<String, dynamic> json) {
    return FrameMetricModel(
      timestampMicros: json['timestampMicros'] as int,
      buildDurationMicros: json['buildDurationMicros'] as int,
      rasterDurationMicros: json['rasterDurationMicros'] as int,
      totalDurationMicros: json['totalDurationMicros'] as int,
      frameNumber: json['frameNumber'] as int,
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
}

/// Model for performance insights.
class PerformanceInsightModel {
  final String type;
  final String title;
  final String description;
  final List<String> suggestions;
  final String severity;
  final Map<String, dynamic>? metadata;

  const PerformanceInsightModel({
    required this.type,
    required this.title,
    required this.description,
    required this.suggestions,
    this.severity = 'warning',
    this.metadata,
  });

  factory PerformanceInsightModel.fromJson(Map<String, dynamic> json) {
    return PerformanceInsightModel(
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      suggestions: (json['suggestions'] as List).cast<String>(),
      severity: json['severity'] as String? ?? 'warning',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'suggestions': suggestions,
      'severity': severity,
      'metadata': metadata,
    };
  }
}

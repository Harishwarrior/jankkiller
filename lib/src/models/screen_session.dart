import 'package:uuid/uuid.dart';

import 'frame_metric.dart';

/// Represents a single screen session in the application's navigation flow.
///
/// A screen session captures the period during which a specific route is active,
/// along with performance metrics collected during that time.
class ScreenSession {
  /// Unique identifier for this session.
  final String sessionId;

  /// The semantic name of the route (e.g., '/home', '/checkout').
  final String routeName;

  /// Monotonic timestamp (microseconds) when the session started.
  final int startTimeMicros;

  /// Monotonic timestamp (microseconds) when the session ended.
  /// Null if the session is still active.
  int? endTimeMicros;

  /// Whether this session represents a popup/dialog rather than a full screen.
  final bool isPopup;

  /// The route that was active before this one (if any).
  final String? previousRoute;

  /// Frame timing metrics collected during this session.
  final List<FrameMetric> frameMetrics;

  /// CPU samples collected during this session (populated by extension).
  Map<String, dynamic>? cpuProfile;

  /// Memory statistics for this session (populated by extension).
  Map<String, dynamic>? memoryStats;

  /// Timeline events detected during this session.
  final List<Map<String, dynamic>> timelineEvents;

  /// Detected performance issues and their suggestions.
  final List<PerformanceInsight> insights;

  ScreenSession({
    String? sessionId,
    required this.routeName,
    required this.startTimeMicros,
    this.endTimeMicros,
    this.isPopup = false,
    this.previousRoute,
    List<FrameMetric>? frameMetrics,
    this.cpuProfile,
    this.memoryStats,
    List<Map<String, dynamic>>? timelineEvents,
    List<PerformanceInsight>? insights,
  }) : sessionId = sessionId ?? const Uuid().v4(),
       frameMetrics = frameMetrics ?? [],
       timelineEvents = timelineEvents ?? [],
       insights = insights ?? [];

  /// Returns the duration of this session in microseconds.
  /// Returns null if the session is still active.
  int? get durationMicros {
    if (endTimeMicros == null) return null;
    return endTimeMicros! - startTimeMicros;
  }

  /// Returns the duration of this session in milliseconds.
  double? get durationMs {
    final micros = durationMicros;
    if (micros == null) return null;
    return micros / 1000.0;
  }

  /// Calculates aggregated frame metrics for this session.
  FrameMetricsAggregate? get aggregateMetrics {
    if (frameMetrics.isEmpty) return null;
    return FrameMetricsAggregate.fromMetrics(frameMetrics);
  }

  /// Ends this session with the given timestamp.
  void end(int endTimeMicros) {
    this.endTimeMicros = endTimeMicros;
  }

  /// Adds a frame metric to this session.
  void addFrameMetric(FrameMetric metric) {
    frameMetrics.add(metric);
  }

  /// Converts this session to JSON for export.
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'routeName': routeName,
      'startTimeMicros': startTimeMicros,
      'endTimeMicros': endTimeMicros,
      'isPopup': isPopup,
      'previousRoute': previousRoute,
      'frameMetrics': frameMetrics.map((m) => m.toJson()).toList(),
      'cpuProfile': cpuProfile,
      'memoryStats': memoryStats,
      'timelineEvents': timelineEvents,
      'insights': insights.map((i) => i.toJson()).toList(),
      'aggregate': aggregateMetrics?.toJson(),
    };
  }

  /// Creates a session from JSON data.
  factory ScreenSession.fromJson(Map<String, dynamic> json) {
    return ScreenSession(
      sessionId: json['sessionId'] as String,
      routeName: json['routeName'] as String,
      startTimeMicros: json['startTimeMicros'] as int,
      endTimeMicros: json['endTimeMicros'] as int?,
      isPopup: json['isPopup'] as bool? ?? false,
      previousRoute: json['previousRoute'] as String?,
      frameMetrics:
          (json['frameMetrics'] as List?)
              ?.map((m) => FrameMetric.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      cpuProfile: json['cpuProfile'] as Map<String, dynamic>?,
      memoryStats: json['memoryStats'] as Map<String, dynamic>?,
      timelineEvents:
          (json['timelineEvents'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      insights:
          (json['insights'] as List?)
              ?.map(
                (i) => PerformanceInsight.fromJson(i as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

/// Aggregated frame metrics for a session.
class FrameMetricsAggregate {
  final double avgBuildMs;
  final double p90BuildMs;
  final double p99BuildMs;
  final double avgRasterMs;
  final double p90RasterMs;
  final double p99RasterMs;
  final int frameCount;
  final int jankyFrameCount;

  const FrameMetricsAggregate({
    required this.avgBuildMs,
    required this.p90BuildMs,
    required this.p99BuildMs,
    required this.avgRasterMs,
    required this.p90RasterMs,
    required this.p99RasterMs,
    required this.frameCount,
    required this.jankyFrameCount,
  });

  /// Creates aggregate metrics from a list of frame metrics.
  factory FrameMetricsAggregate.fromMetrics(List<FrameMetric> metrics) {
    if (metrics.isEmpty) {
      return const FrameMetricsAggregate(
        avgBuildMs: 0,
        p90BuildMs: 0,
        p99BuildMs: 0,
        avgRasterMs: 0,
        p90RasterMs: 0,
        p99RasterMs: 0,
        frameCount: 0,
        jankyFrameCount: 0,
      );
    }

    final buildTimes = metrics.map((m) => m.buildDurationMs).toList()..sort();
    final rasterTimes = metrics.map((m) => m.rasterDurationMs).toList()..sort();

    return FrameMetricsAggregate(
      avgBuildMs: buildTimes.reduce((a, b) => a + b) / buildTimes.length,
      p90BuildMs: _percentile(buildTimes, 0.90),
      p99BuildMs: _percentile(buildTimes, 0.99),
      avgRasterMs: rasterTimes.reduce((a, b) => a + b) / rasterTimes.length,
      p90RasterMs: _percentile(rasterTimes, 0.90),
      p99RasterMs: _percentile(rasterTimes, 0.99),
      frameCount: metrics.length,
      jankyFrameCount: metrics.where((m) => m.totalDurationMs > 16.67).length,
    );
  }

  static double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;
    final index = (sortedValues.length * percentile).floor();
    return sortedValues[index.clamp(0, sortedValues.length - 1)];
  }

  Map<String, dynamic> toJson() {
    return {
      'avgBuildMs': avgBuildMs,
      'p90BuildMs': p90BuildMs,
      'p99BuildMs': p99BuildMs,
      'avgRasterMs': avgRasterMs,
      'p90RasterMs': p90RasterMs,
      'p99RasterMs': p99RasterMs,
      'frameCount': frameCount,
      'jankyFrameCount': jankyFrameCount,
    };
  }

  factory FrameMetricsAggregate.fromJson(Map<String, dynamic> json) {
    return FrameMetricsAggregate(
      avgBuildMs: (json['avgBuildMs'] as num).toDouble(),
      p90BuildMs: (json['p90BuildMs'] as num).toDouble(),
      p99BuildMs: (json['p99BuildMs'] as num).toDouble(),
      avgRasterMs: (json['avgRasterMs'] as num).toDouble(),
      p90RasterMs: (json['p90RasterMs'] as num).toDouble(),
      p99RasterMs: (json['p99RasterMs'] as num).toDouble(),
      frameCount: json['frameCount'] as int,
      jankyFrameCount: json['jankyFrameCount'] as int,
    );
  }
}

/// Represents a detected performance issue with suggested fixes.
class PerformanceInsight {
  final String type;
  final String title;
  final String description;
  final List<String> suggestions;
  final String severity; // 'info', 'warning', 'critical'
  final Map<String, dynamic>? metadata;

  const PerformanceInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.suggestions,
    this.severity = 'warning',
    this.metadata,
  });

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

  factory PerformanceInsight.fromJson(Map<String, dynamic> json) {
    return PerformanceInsight(
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      suggestions: (json['suggestions'] as List).cast<String>(),
      severity: json['severity'] as String? ?? 'warning',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

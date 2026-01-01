import '../models/screen_session_model.dart';

/// Insight engine that analyzes session data to detect performance anti-patterns.
class InsightEngine {
  InsightEngine._();
  static final instance = InsightEngine._();

  /// Analyzes a session and returns detected performance insights.
  List<PerformanceInsightModel> analyze(ScreenSessionModel session) {
    final insights = <PerformanceInsightModel>[];

    // Only analyze completed sessions with frames
    if (session.isActive || session.frameMetrics.isEmpty) {
      return insights;
    }

    // Heuristic 1: Excessive Jank
    _detectExcessiveJank(session, insights);

    // Heuristic 2: High Build Times
    _detectHighBuildTimes(session, insights);

    // Heuristic 3: High Raster Times
    _detectHighRasterTimes(session, insights);

    // Heuristic 4: Build Storm
    _detectBuildStorm(session, insights);

    // Timeline-based heuristics would go here
    // (requires timeline events to be populated)
    _detectSaveLayerBleed(session, insights);
    _detectShaderJank(session, insights);
    _detectIntrinsicLayout(session, insights);

    return insights;
  }

  void _detectExcessiveJank(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    final jankPercentage = session.jankPercentage;

    if (jankPercentage >= 10) {
      insights.add(PerformanceInsightModel(
        type: 'excessive_jank',
        title: 'Excessive Frame Jank',
        description:
            '${jankPercentage.toStringAsFixed(1)}% of frames exceeded the 16.67ms target. '
            'This results in visible stuttering and poor user experience.',
        suggestions: [
          'Profile the screen to identify expensive operations',
          'Move heavy computations to isolates using compute()',
          'Reduce widget tree complexity',
          'Use const constructors where possible',
        ],
        severity: jankPercentage >= 20 ? 'critical' : 'warning',
        metadata: {
          'jankPercentage': jankPercentage,
          'jankyFrames': session.jankyFrameCount,
          'totalFrames': session.frameMetrics.length,
        },
      ));
    }
  }

  void _detectHighBuildTimes(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    final avgBuildMs = session.avgBuildMs;

    if (avgBuildMs > 8) {
      insights.add(PerformanceInsightModel(
        type: 'high_build_time',
        title: 'High Average Build Time',
        description:
            'Average build time is ${avgBuildMs.toStringAsFixed(2)}ms, '
            'which is above the recommended 8ms threshold for 60fps.',
        suggestions: [
          'Push setState calls down to leaf widgets',
          'Use const constructors for static widgets',
          'Consider using Selector/Consumer to filter rebuilds',
          'Avoid building complex widgets inline',
        ],
        severity: avgBuildMs > 12 ? 'critical' : 'warning',
        metadata: {'avgBuildMs': avgBuildMs},
      ));
    }
  }

  void _detectHighRasterTimes(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    final avgRasterMs = session.avgRasterMs;

    if (avgRasterMs > 8) {
      insights.add(PerformanceInsightModel(
        type: 'high_raster_time',
        title: 'High Average Raster Time',
        description:
            'Average raster time is ${avgRasterMs.toStringAsFixed(2)}ms, '
            'indicating GPU-intensive rendering operations.',
        suggestions: [
          'Avoid Opacity widgets with saveLayer',
          'Reduce use of shadows and complex clipping',
          'Use RepaintBoundary to cache static subtrees',
          'Consider simplifying visual effects',
        ],
        severity: avgRasterMs > 12 ? 'critical' : 'warning',
        metadata: {'avgRasterMs': avgRasterMs},
      ));
    }
  }

  void _detectBuildStorm(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    // Detect frames with extremely high build times relative to others
    final frames = session.frameMetrics;
    if (frames.length < 10) return;

    final avgBuild = session.avgBuildMs;
    final stormFrames =
        frames.where((f) => f.buildDurationMs > avgBuild * 3).length;

    if (stormFrames > frames.length * 0.1) {
      insights.add(PerformanceInsightModel(
        type: 'build_storm',
        title: 'Build Storm Detected',
        description:
            '$stormFrames frames had build times 3x higher than average. '
            'This suggests excessive widget rebuilding in response to state changes.',
        suggestions: [
          'Review setState() calls for over-reaching scope',
          'Consider using ValueNotifier/ValueListenableBuilder',
          'Break large widgets into smaller, focused components',
          'Use keys judiciously to preserve widget state',
        ],
        severity: 'warning',
        metadata: {
          'stormFrames': stormFrames,
          'avgBuildMs': avgBuild,
        },
      ));
    }
  }

  void _detectSaveLayerBleed(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    // Check timeline events for saveLayer
    final saveLayerEvents = session.timelineEvents
        .where((e) =>
            (e['name'] as String?)?.contains('saveLayer') == true ||
            (e['name'] as String?)?.contains('Canvas::saveLayer') == true)
        .toList();

    if (saveLayerEvents.isNotEmpty) {
      insights.add(PerformanceInsightModel(
        type: 'save_layer_bleed',
        title: 'SaveLayer Operations Detected',
        description: 'Detected ${saveLayerEvents.length} saveLayer operations. '
            'Each saveLayer forces GPU to switch render targets, causing high raster costs.',
        suggestions: [
          'Replace Opacity with color alpha (e.g., Color.withOpacity)',
          'Use FadeInImage for image transitions',
          'Avoid ShaderMask where possible',
          'Wrap static subtrees in RepaintBoundary to cache',
        ],
        severity: saveLayerEvents.length > 5 ? 'critical' : 'warning',
        metadata: {'saveLayerCount': saveLayerEvents.length},
      ));
    }
  }

  void _detectShaderJank(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    // Check for shader compilation events
    final shaderEvents = session.timelineEvents
        .where((e) =>
            (e['name'] as String?)?.contains('GrGLProgramBuilder') == true ||
            (e['name'] as String?)?.contains('finalize') == true)
        .toList();

    if (shaderEvents.isNotEmpty) {
      insights.add(PerformanceInsightModel(
        type: 'shader_jank',
        title: 'Shader Compilation Jank',
        description: 'Shader compilation detected. '
            'This causes significant jank on first run of animations.',
        suggestions: [
          'Use --cache-sksl flag during profiling to capture shaders',
          'Pre-warm shaders on app startup',
          'Consider Impeller renderer (eliminates shader jank)',
          'Simplify complex shader operations',
        ],
        severity: 'warning',
        metadata: {'shaderEventCount': shaderEvents.length},
      ));
    }
  }

  void _detectIntrinsicLayout(
    ScreenSessionModel session,
    List<PerformanceInsightModel> insights,
  ) {
    // Check for intrinsic layout events
    final intrinsicEvents = session.timelineEvents
        .where((e) =>
            (e['name'] as String?)?.toLowerCase().contains('intrinsic') == true)
        .toList();

    if (intrinsicEvents.isNotEmpty) {
      insights.add(PerformanceInsightModel(
        type: 'intrinsic_layout',
        title: 'Intrinsic Layout Operations',
        description: 'IntrinsicWidth/IntrinsicHeight widgets detected. '
            'These force multiple layout passes, turning O(N) into O(N²).',
        suggestions: [
          'Avoid IntrinsicHeight/Width in lists or deep trees',
          'Use Flex, Expanded, or fixed constraints instead',
          'Pre-compute sizes if possible',
          'Consider CustomSingleChildLayout for complex cases',
        ],
        severity: 'warning',
        metadata: {'intrinsicEventCount': intrinsicEvents.length},
      ));
    }
  }
}

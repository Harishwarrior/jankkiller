/// A Flutter DevTools extension for context-aware screen-flow performance
/// profiling and regression analysis.
///
/// This package provides instrumentation for capturing navigation events,
/// frame timing metrics, and performance data segmented by screen sessions.
library jankkiller;

export 'src/collector/frame_timing_collector.dart';
export 'src/jankkiller_controller.dart';
export 'src/models/frame_metric.dart';
export 'src/models/screen_session.dart';
export 'src/observer/performance_navigator_observer.dart';

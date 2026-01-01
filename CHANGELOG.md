# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-01-01

### Added

- Initial release of JankKiller
- Core instrumentation library for capturing frame timing metrics
- `JankKillerController` for managing performance collection
- `PerformanceNavigatorObserver` for tracking route lifecycle events
- `FrameTimingCollector` for capturing frame rendering metrics
- DevTools extension for visualizing performance data
- Session-based performance segmentation
- Real-time frame timing charts
- Automated performance insights engine with heuristics:
  - Excessive jank detection
  - High build/raster time detection
  - Build storm detection
  - SaveLayer operation detection
  - Shader compilation jank detection
  - Intrinsic layout operation detection
- Session comparison view for regression analysis
- CPU profile integration
- Timeline events integration
- Export/import functionality for performance baselines
- Example app demonstrating usage
- Comprehensive documentation

### Features

- Screen-aware performance profiling
- Automatic frame metric batching (30 frames per batch)
- Support for popup routes (dialogs, bottom sheets)
- Material Design 3 UI in DevTools extension
- Session list view with filtering
- Detailed session view with charts and insights
- Performance comparison across multiple sessions

[0.0.1]: https://github.com/Harishwarrior/jankkiller/releases/tag/v0.0.1

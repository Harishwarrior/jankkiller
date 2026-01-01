import 'package:flutter/material.dart';

import '../../models/screen_session_model.dart';
import '../widgets/frame_chart.dart';

/// View for comparing two screen sessions (Baseline vs Candidate).
class ComparisonView extends StatelessWidget {
  final ScreenSessionModel baseline;
  final ScreenSessionModel candidate;

  const ComparisonView({
    super.key,
    required this.baseline,
    required this.candidate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regression Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Row(
        children: [
          // Baseline Column
          Expanded(
            child: _SessionColumn(
              title: 'BASELINE',
              session: baseline,
              color: Colors.blue,
            ),
          ),
          const VerticalDivider(width: 1),
          // Candidate Column
          Expanded(
            child: _SessionColumn(
              title: 'CANDIDATE',
              session: candidate,
              color: Colors.orange,
              comparisonBaseline: baseline,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionColumn extends StatelessWidget {
  final String title;
  final ScreenSessionModel session;
  final Color color;
  final ScreenSessionModel? comparisonBaseline;

  const _SessionColumn({
    required this.title,
    required this.session,
    required this.color,
    this.comparisonBaseline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session.routeName,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Summary Metrics
          _ComparisonSummary(
            session: session,
            baseline: comparisonBaseline,
          ),
          const SizedBox(height: 24),
          // Frame Chart
          const Text(
            'Performance Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FrameChart(session: session),
          ),
        ],
      ),
    );
  }
}

class _ComparisonSummary extends StatelessWidget {
  final ScreenSessionModel session;
  final ScreenSessionModel? baseline;

  const _ComparisonSummary({required this.session, this.baseline});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _MetricDeltaCard(
          label: 'Avg Build',
          value: '${session.avgBuildMs.toStringAsFixed(2)}ms',
          delta: baseline != null
              ? session.avgBuildMs - baseline!.avgBuildMs
              : null,
          suffix: 'ms',
        ),
        _MetricDeltaCard(
          label: 'Avg Raster',
          value: '${session.avgRasterMs.toStringAsFixed(2)}ms',
          delta: baseline != null
              ? session.avgRasterMs - baseline!.avgRasterMs
              : null,
          suffix: 'ms',
        ),
        _MetricDeltaCard(
          label: 'Jank Rate',
          value: '${session.jankPercentage.toStringAsFixed(1)}%',
          delta: baseline != null
              ? session.jankPercentage - baseline!.jankPercentage
              : null,
          suffix: '%',
          inverseSeverity: true, // Higher is worse
        ),
      ],
    );
  }
}

class _MetricDeltaCard extends StatelessWidget {
  final String label;
  final String value;
  final double? delta;
  final String suffix;
  final bool inverseSeverity;

  const _MetricDeltaCard({
    required this.label,
    required this.value,
    this.delta,
    required this.suffix,
    this.inverseSeverity = true,
  });

  @override
  Widget build(BuildContext context) {
    Color? deltaColor;
    String deltaText = '';

    if (delta != null) {
      final isBetter = inverseSeverity ? delta! < 0 : delta! > 0;
      final isWorse =
          inverseSeverity ? delta! > 0.5 : delta! < -0.5; // Threshold for color

      if (isBetter) {
        deltaColor = Colors.green;
      } else if (isWorse) {
        deltaColor = Colors.red;
      }

      deltaText = '${delta! > 0 ? "+" : ""}${delta!.toStringAsFixed(2)}$suffix';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (delta != null) ...[
              const SizedBox(height: 4),
              Text(
                deltaText,
                style: TextStyle(
                  fontSize: 12,
                  color: deltaColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

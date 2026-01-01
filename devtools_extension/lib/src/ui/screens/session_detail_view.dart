import 'package:flutter/material.dart';

import '../../models/screen_session_model.dart';
import '../../services/session_manager.dart';
import '../widgets/frame_chart.dart';
import '../widgets/insights_panel.dart';

/// Detail view for a selected screen session.
class SessionDetailView extends StatefulWidget {
  final String sessionId;
  final SessionManager sessionManager;

  const SessionDetailView({
    super.key,
    required this.sessionId,
    required this.sessionManager,
  });

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.sessionManager,
      builder: (context, _) {
        // Always get the latest session data from the manager
        final session = widget.sessionManager.sessions
            .where((s) => s.sessionId == widget.sessionId)
            .firstOrNull;

        if (session == null) {
          return const Center(
            child: Text(
              'Session no longer available',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with route name and status
              _buildHeader(context, theme, session),
              const SizedBox(height: 24),

              // Summary cards
              _buildSummaryCards(context, theme, session),
              const SizedBox(height: 24),

              // Frame timing chart
              Text(
                'Frame Timing',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: SizedBox(
                  height: 250,
                  child: FrameChart(session: session),
                ),
              ),
              const SizedBox(height: 24),

              // Insights panel
              if (session.insights.isNotEmpty) ...[
                Text(
                  'Performance Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                InsightsPanel(insights: session.insights),
                const SizedBox(height: 24),
              ],

              // Frame details table
              Text(
                'Frame Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildFrameTable(context, theme, session),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, ScreenSessionModel session) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.routeName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Session ID: ${session.sessionId.substring(0, 8)}...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        if (session.isActive)
          Chip(
            label: const Text('ACTIVE'),
            backgroundColor: Colors.green.withValues(alpha: 0.2),
            labelStyle: const TextStyle(color: Colors.green),
          ),
        if (session.isPopup)
          const Chip(
            label: Text('POPUP'),
            backgroundColor: Colors.blueGrey,
          ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, ThemeData theme, ScreenSessionModel session) {
    final jankPercentage = session.jankPercentage;
    Color healthColor;
    String healthLabel;

    if (jankPercentage == 0) {
      healthColor = Colors.green;
      healthLabel = 'Excellent';
    } else if (jankPercentage < 2) {
      healthColor = Colors.lightGreen;
      healthLabel = 'Good';
    } else if (jankPercentage < 5) {
      healthColor = Colors.orange;
      healthLabel = 'Fair';
    } else {
      healthColor = Colors.red;
      healthLabel = 'Poor';
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _SummaryCard(
          key: ValueKey('frames_${session.frameMetrics.length}_${session.jankyFrameCount}'),
          title: 'Frames',
          value: '${session.frameMetrics.length}',
          subtitle: '${session.jankyFrameCount} janky',
          icon: Icons.photo_filter,
          color: theme.colorScheme.primary,
        ),
        _SummaryCard(
          key: ValueKey('jank_${jankPercentage.toStringAsFixed(1)}'),
          title: 'Jank Rate',
          value: '${jankPercentage.toStringAsFixed(1)}%',
          subtitle: healthLabel,
          icon: Icons.speed,
          color: healthColor,
        ),
        _SummaryCard(
          key: ValueKey('build_${session.avgBuildMs.toStringAsFixed(2)}'),
          title: 'Avg Build',
          value: '${session.avgBuildMs.toStringAsFixed(2)}ms',
          subtitle: session.avgBuildMs > 8 ? 'Above target' : 'On target',
          icon: Icons.build,
          color: session.avgBuildMs > 8 ? Colors.orange : Colors.green,
        ),
        _SummaryCard(
          key: ValueKey('raster_${session.avgRasterMs.toStringAsFixed(2)}'),
          title: 'Avg Raster',
          value: '${session.avgRasterMs.toStringAsFixed(2)}ms',
          subtitle: session.avgRasterMs > 8 ? 'Above target' : 'On target',
          icon: Icons.brush,
          color: session.avgRasterMs > 8 ? Colors.orange : Colors.green,
        ),
        if (session.durationMs != null)
          _SummaryCard(
            key: ValueKey('duration_${session.durationMs}'),
            title: 'Duration',
            value: '${(session.durationMs! / 1000).toStringAsFixed(2)}s',
            subtitle: 'Total time on screen',
            icon: Icons.timer,
            color: theme.colorScheme.secondary,
          ),
      ],
    );
  }

  Widget _buildFrameTable(BuildContext context, ThemeData theme, ScreenSessionModel session) {
    if (session.frameMetrics.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No frames captured yet'),
          ),
        ),
      );
    }

    // Show last 50 frames
    final frames = session.frameMetrics.reversed.take(50).toList();

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Build (ms)')),
            DataColumn(label: Text('Raster (ms)')),
            DataColumn(label: Text('Total (ms)')),
            DataColumn(label: Text('Status')),
          ],
          rows: frames.map((frame) {
            final isJanky = frame.isJanky;
            return DataRow(
              color: WidgetStateProperty.all(
                isJanky ? Colors.red.withValues(alpha: 0.1) : null,
              ),
              cells: [
                DataCell(Text('${frame.frameNumber}')),
                DataCell(Text(frame.buildDurationMs.toStringAsFixed(2))),
                DataCell(Text(frame.rasterDurationMs.toStringAsFixed(2))),
                DataCell(Text(frame.totalDurationMs.toStringAsFixed(2))),
                DataCell(
                  isJanky
                      ? const Icon(Icons.warning, color: Colors.red, size: 18)
                      : const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Summary card widget.
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/screen_session_model.dart';
import '../../services/session_manager.dart';

/// View displaying the list of captured screen sessions.
class SessionListView extends StatelessWidget {
  final SessionManager sessionManager;
  final ScreenSessionModel? selectedSession;
  final ValueChanged<ScreenSessionModel?> onSessionSelected;

  const SessionListView({
    super.key,
    required this.sessionManager,
    required this.selectedSession,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sessionManager,
      builder: (context, _) {
        final sessions = sessionManager.sessions;

        if (sessions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No sessions captured yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Navigate between screens in your app to see sessions here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session =
                sessions[sessions.length - 1 - index]; // Reverse order
            final isSelected = session.sessionId == selectedSession?.sessionId;

            return SessionListTile(
              session: session,
              isSelected: isSelected,
              onTap: () => onSessionSelected(session),
            );
          },
        );
      },
    );
  }
}

/// Individual tile for a session in the list.
class SessionListTile extends StatelessWidget {
  final ScreenSessionModel session;
  final bool isSelected;
  final VoidCallback onTap;

  const SessionListTile({
    super.key,
    required this.session,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jankPercentage = session.jankPercentage;

    // Determine health color based on jank percentage
    Color healthColor;
    if (jankPercentage == 0) {
      healthColor = Colors.green;
    } else if (jankPercentage < 5) {
      healthColor = Colors.orange;
    } else {
      healthColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Route name
                  Expanded(
                    child: Text(
                      session.routeName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status indicator
                  if (session.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    )
                  else if (session.isPopup)
                    const Icon(Icons.widgets, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              // Metrics row
              Row(
                children: [
                  // Frame count
                  _MetricChip(
                    icon: Icons.photo_filter,
                    label: '${session.frameMetrics.length}',
                    tooltip: 'Frames',
                  ),
                  const SizedBox(width: 8),
                  // Jank indicator
                  if (session.frameMetrics.isNotEmpty) ...[
                    _MetricChip(
                      icon: Icons.warning_amber,
                      label: '${jankPercentage.toStringAsFixed(1)}%',
                      tooltip: 'Jank',
                      color: healthColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Duration
                  if (session.durationMs != null)
                    _MetricChip(
                      icon: Icons.timer,
                      label: '${session.durationMs!.toStringAsFixed(0)}ms',
                      tooltip: 'Duration',
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Build/Raster times
              if (session.frameMetrics.isNotEmpty)
                Text(
                  'Build: ${session.avgBuildMs.toStringAsFixed(2)}ms  |  '
                  'Raster: ${session.avgRasterMs.toStringAsFixed(2)}ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small chip widget for displaying metrics.
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color? color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

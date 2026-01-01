import 'package:flutter/material.dart';

import '../../models/screen_session_model.dart';

/// Panel displaying performance insights and suggestions.
class InsightsPanel extends StatelessWidget {
  final List<PerformanceInsightModel> insights;

  const InsightsPanel({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          insights.map((insight) => InsightCard(insight: insight)).toList(),
    );
  }
}

/// Individual insight card.
class InsightCard extends StatelessWidget {
  final PerformanceInsightModel insight;

  const InsightCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color severityColor;
    IconData severityIcon;

    switch (insight.severity) {
      case 'critical':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'warning':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      case 'info':
      default:
        severityColor = Colors.blue;
        severityIcon = Icons.info;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: severityColor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        leading: Icon(severityIcon, color: severityColor),
        title: Text(
          insight.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          insight.type,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  insight.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Suggestions
                Text(
                  'Suggestions:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...insight.suggestions.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: severityColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

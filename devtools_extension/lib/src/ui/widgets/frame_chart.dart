import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/screen_session_model.dart';

/// Chart widget displaying frame build and raster times.
class FrameChart extends StatelessWidget {
  final ScreenSessionModel session;

  const FrameChart({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.frameMetrics.isEmpty) {
      return const Card(
        child: Center(
          child: Text('No frame data available'),
        ),
      );
    }

    final frames = session.frameMetrics;
    final maxY = _calculateMaxY(frames);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend
            Row(
              children: [
                const _LegendItem(color: Colors.blue, label: 'Build'),
                const SizedBox(width: 16),
                const _LegendItem(color: Colors.orange, label: 'Raster'),
                const SizedBox(width: 16),
                _LegendItem(
                  color: Colors.red.withValues(alpha: 0.3),
                  label: 'Jank threshold (16.67ms)',
                  isDashed: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Chart
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      axisNameWidget: const Text(
                        'ms',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (frames.length / 5)
                            .ceilToDouble()
                            .clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      axisNameWidget: const Text(
                        'Frame',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // 16.67ms jank threshold line
                      HorizontalLine(
                        y: 16.67,
                        color: Colors.red.withValues(alpha: 0.5),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                  lineBarsData: [
                    // Build time line
                    LineChartBarData(
                      spots: _createSpots(frames, (f) => f.buildDurationMs),
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: Colors.blue,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                    // Raster time line
                    LineChartBarData(
                      spots: _createSpots(frames, (f) => f.rasterDurationMs),
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: Colors.orange,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.orange,
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final isRaster = spot.barIndex == 1;
                          return LineTooltipItem(
                            '${isRaster ? "Raster" : "Build"}: ${spot.y.toStringAsFixed(2)}ms',
                            TextStyle(
                              color: isRaster ? Colors.orange : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY(List<FrameMetricModel> frames) {
    double maxBuild = 0;
    double maxRaster = 0;

    for (final frame in frames) {
      if (frame.buildDurationMs > maxBuild) maxBuild = frame.buildDurationMs;
      if (frame.rasterDurationMs > maxRaster) {
        maxRaster = frame.rasterDurationMs;
      }
    }

    final max = maxBuild > maxRaster ? maxBuild : maxRaster;
    // Ensure we show the 16.67ms line even if all frames are fast
    return (max < 20 ? 25 : max * 1.2).ceilToDouble();
  }

  List<FlSpot> _createSpots(
    List<FrameMetricModel> frames,
    double Function(FrameMetricModel) getValue,
  ) {
    return frames.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), getValue(entry.value));
    }).toList();
  }
}

/// Legend item widget.
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed
                ? Border(
                    bottom: BorderSide(
                      color: color,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

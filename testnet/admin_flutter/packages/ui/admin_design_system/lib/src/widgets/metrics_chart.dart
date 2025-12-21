import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';
import '../theme/admin_spacing.dart';

/// Data point for metrics chart
class MetricsDataPoint {
  final DateTime timestamp;
  final double value;

  const MetricsDataPoint({
    required this.timestamp,
    required this.value,
  });
}

/// A line chart widget for displaying metrics over time
class MetricsChart extends StatelessWidget {
  final List<MetricsDataPoint> data;
  final String title;
  final Color? lineColor;
  final String Function(double)? formatValue;
  final double height;

  const MetricsChart({
    super.key,
    required this.data,
    required this.title,
    this.lineColor,
    this.formatValue,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AdminColors.textSecondaryDark
                      : AdminColors.textSecondaryLight,
                ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = lineColor ?? AdminColors.primary;
    final gridColor = isDark
        ? AdminColors.borderDark.withValues(alpha: 0.3)
        : AdminColors.borderLight.withValues(alpha: 0.3);

    final sortedData = List<MetricsDataPoint>.from(data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = sortedData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    // Guard against empty spots list (shouldn't happen if data.isNotEmpty, but be safe)
    if (spots.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No valid data points')),
      );
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    // Use minimum padding of 1.0 to avoid zero padding when all values are equal
    final padding = math.max((maxY - minY) * 0.1, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AdminSpacing.sm),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateInterval(maxY - minY),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      final formatted = formatValue != null
                          ? formatValue!(value)
                          : _formatNumber(value);
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          formatted,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? AdminColors.textTertiaryDark
                                    : AdminColors.textTertiaryLight,
                              ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: _calculateTimeInterval(sortedData.length),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sortedData.length) {
                        return const SizedBox.shrink();
                      }
                      final time = sortedData[index].timestamp;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _formatTime(time),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? AdminColors.textTertiaryDark
                                    : AdminColors.textTertiaryLight,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: minY > 0 ? (minY - padding).clamp(0, double.infinity) : minY - padding,
              maxY: maxY + padding,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark
                      ? AdminColors.surfaceDark
                      : AdminColors.surfaceLight,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < 0 || index >= sortedData.length) {
                        return null;
                      }
                      final point = sortedData[index];
                      final formattedValue = formatValue != null
                          ? formatValue!(point.value)
                          : _formatNumber(point.value);
                      return LineTooltipItem(
                        '$formattedValue\n${_formatDateTime(point.timestamp)}',
                        TextStyle(
                          color: isDark
                              ? AdminColors.textPrimaryDark
                              : AdminColors.textPrimaryLight,
                          fontSize: 12,
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
    );
  }

  double _calculateInterval(double range) {
    if (range <= 0) return 1;
    if (range < 10) return 1;
    if (range < 100) return 10;
    if (range < 1000) return 100;
    return (range / 5).roundToDouble();
  }

  double _calculateTimeInterval(int dataPoints) {
    if (dataPoints <= 5) return 1;
    if (dataPoints <= 10) return 2;
    if (dataPoints <= 20) return 4;
    return (dataPoints / 5).roundToDouble();
  }

  String _formatNumber(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}G';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(1);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.month}/${time.day} ${_formatTime(time)}';
  }
}

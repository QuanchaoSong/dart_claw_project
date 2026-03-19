import 'dart:convert';
import 'package:dart_claw/pages/home/view/claw_chat_item_subviews/chart_full_screen_view.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChartCardView extends StatelessWidget {
  const ChartCardView({super.key, required this.record});

  final ClawToolCallRecord record;

  // ── Result parsing ──────────────────────────────────────────────────────

  /// Returns the decoded args map from '[chart displayed:{...}]', or null.
  Map<String, dynamic>? _parseChartArgs() {
    final result = record.result ?? '';
    const prefix = '[chart displayed:';
    if (result.startsWith(prefix) && result.endsWith(']')) {
      final json = result.substring(prefix.length, result.length - 1);
      try {
        return jsonDecode(json) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Color _seriesColor(int index) {
    const palette = [
      Color(0xFF4FC3F7), // blue
      Color(0xFFA5D6A7), // green
      Color(0xFFFFB74D), // orange
      Color(0xFFF48FB1), // pink
      Color(0xFFCE93D8), // purple
      Color(0xFF80DEEA), // cyan
      Color(0xFFFFCC80), // amber
    ];
    return palette[index % palette.length];
  }

  // ── Chart builders ──────────────────────────────────────────────────────

  Widget _buildChart(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'line';
    final title = data['title'] as String?;
    final xLabel = data['x_label'] as String?;
    final yLabel = data['y_label'] as String?;
    final rawSeries = data['series'] as List<dynamic>;

    final titleWidget = title != null
        ? ChartTitle(
            text: title,
            textStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          )
        : null;

    final primaryXAxis = CategoryAxis(
      title: AxisTitle(
        text: xLabel ?? '',
        textStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
      majorGridLines: const MajorGridLines(color: Colors.white10),
      axisLine: const AxisLine(color: Colors.white12),
      majorTickLines: const MajorTickLines(color: Colors.white12),
    );

    final primaryYAxis = NumericAxis(
      title: AxisTitle(
        text: yLabel ?? '',
        textStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
      majorGridLines: const MajorGridLines(color: Colors.white10),
      axisLine: const AxisLine(color: Colors.white12),
      majorTickLines: const MajorTickLines(color: Colors.white12),
    );

    final legend = Legend(
      isVisible: rawSeries.length > 1,
      textStyle: const TextStyle(color: Colors.white54, fontSize: 11),
      overflowMode: LegendItemOverflowMode.wrap,
    );

    if (type == 'pie') {
      return _buildPieChart(rawSeries, titleWidget);
    }

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      plotAreaBorderColor: Colors.transparent,
      title: titleWidget ?? const ChartTitle(text: ''),
      primaryXAxis: primaryXAxis,
      primaryYAxis: primaryYAxis,
      legend: legend,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: const Color(0xFF2C2C2E),
        textStyle: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
      series: _buildCartesianSeries(type, rawSeries),
    );
  }

  List<CartesianSeries<Map<String, dynamic>, String>>
      _buildCartesianSeries(String type, List<dynamic> rawSeries) {
    final result =
        <CartesianSeries<Map<String, dynamic>, String>>[];
    for (var i = 0; i < rawSeries.length; i++) {
      final s = rawSeries[i] as Map<String, dynamic>;
      final name = s['name'] as String? ?? 'Series ${i + 1}';
      final data = (s['data'] as List<dynamic>)
          .map((pt) => Map<String, dynamic>.from(pt as Map))
          .toList();
      final color = _seriesColor(i);

      switch (type) {
        case 'bar':
          result.add(ColumnSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: data,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            borderRadius: BorderRadius.circular(3),
          ));
        case 'area':
          result.add(AreaSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: data,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color.withOpacity(0.55),
            borderColor: color,
            borderWidth: 1.5,
          ));
        case 'scatter':
          result.add(ScatterSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: data,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            markerSettings: const MarkerSettings(height: 8, width: 8),
          ));
        default: // line
          result.add(LineSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: data,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            width: 1.8,
            markerSettings: MarkerSettings(
              isVisible: data.length <= 20,
              color: color,
              borderWidth: 0,
              height: 6,
              width: 6,
            ),
          ));
      }
    }
    return result;
  }

  Widget _buildPieChart(
      List<dynamic> rawSeries, ChartTitle? titleWidget) {
    final s = rawSeries.first as Map<String, dynamic>;
    final data = (s['data'] as List<dynamic>)
        .map((pt) => Map<String, dynamic>.from(pt as Map))
        .toList();

    return SfCircularChart(
      backgroundColor: Colors.transparent,
      title: titleWidget ?? const ChartTitle(text: ''),
      legend: const Legend(
        isVisible: true,
        textStyle: TextStyle(color: Colors.white54, fontSize: 11),
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: const Color(0xFF2C2C2E),
        textStyle: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
      series: [
        PieSeries<Map<String, dynamic>, String>(
          dataSource: data,
          xValueMapper: (pt, _) => pt['x'].toString(),
          yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
          pointColorMapper: (_, i) => _seriesColor(i),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: switch (record.status) {
        ClawToolStatus.pending || ClawToolStatus.running => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(radius: 7),
                SizedBox(width: 8),
                Text('Rendering chart…',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ClawToolStatus.success => _buildSuccess(context),
        _ => Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    record.result ?? 'Failed to render chart',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final data = _parseChartArgs();
    if (data == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Failed to parse chart data',
            style: TextStyle(color: Colors.red, fontSize: 12)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          SizedBox(height: 280, child: _buildChart(data)),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: '展开',
              child: GestureDetector(
                onTap: () => ChartFullScreenView.show(context, data),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.open_in_full,
                      size: 13, color: Colors.white38),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

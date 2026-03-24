import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// 手机端图表卡片，直接接收 show_chart args Map（与桌面端逻辑相同，去除 ClawToolCallRecord 依赖）。
class ChartCardView extends StatelessWidget {
  const ChartCardView({super.key, required this.data});

  /// show_chart 工具的 args: {type, title?, x_label?, y_label?, series}
  final Map<String, dynamic> data;

  // ── 颜色调色板 ─────────────────────────────────────────────────────────────

  static Color _seriesColor(int index) {
    const palette = [
      Color(0xFF4FC3F7),
      Color(0xFFA5D6A7),
      Color(0xFFFFB74D),
      Color(0xFFF48FB1),
      Color(0xFFCE93D8),
      Color(0xFF80DEEA),
      Color(0xFFFFCC80),
    ];
    return palette[index % palette.length];
  }

  // ── Chart builders ─────────────────────────────────────────────────────────

  Widget _buildChart() {
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

    if (type == 'pie') return _buildPie(rawSeries, titleWidget);

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      plotAreaBorderColor: Colors.transparent,
      title: titleWidget ?? const ChartTitle(text: ''),
      primaryXAxis: CategoryAxis(
        title: AxisTitle(
          text: xLabel ?? '',
          textStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        majorGridLines: const MajorGridLines(color: Colors.white10),
        axisLine: const AxisLine(color: Colors.white12),
        majorTickLines: const MajorTickLines(color: Colors.white12),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: yLabel ?? '',
          textStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        majorGridLines: const MajorGridLines(color: Colors.white10),
        axisLine: const AxisLine(color: Colors.white12),
        majorTickLines: const MajorTickLines(color: Colors.white12),
      ),
      legend: Legend(
        isVisible: rawSeries.length > 1,
        textStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: const Color(0xFF2C2C2E),
        textStyle: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
      series: _buildCartesianSeries(type, rawSeries),
    );
  }

  List<CartesianSeries<Map<String, dynamic>, String>> _buildCartesianSeries(
      String type, List<dynamic> rawSeries) {
    final result = <CartesianSeries<Map<String, dynamic>, String>>[];
    for (var i = 0; i < rawSeries.length; i++) {
      final s = rawSeries[i] as Map<String, dynamic>;
      final name = s['name'] as String? ?? 'Series ${i + 1}';
      final pts = (s['data'] as List<dynamic>)
          .map((pt) => Map<String, dynamic>.from(pt as Map))
          .toList();
      final color = _seriesColor(i);

      switch (type) {
        case 'bar':
          result.add(ColumnSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: pts,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            borderRadius: BorderRadius.circular(3),
          ));
        case 'area':
          result.add(AreaSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: pts,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color.withOpacity(0.55),
            borderColor: color,
            borderWidth: 1.5,
          ));
        case 'scatter':
          result.add(ScatterSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: pts,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            markerSettings: const MarkerSettings(height: 8, width: 8),
          ));
        default: // line
          result.add(LineSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: pts,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            width: 1.8,
            markerSettings: MarkerSettings(
              isVisible: pts.length <= 20,
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

  Widget _buildPie(List<dynamic> rawSeries, ChartTitle? titleWidget) {
    final s = rawSeries.first as Map<String, dynamic>;
    final pts = (s['data'] as List<dynamic>)
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
          dataSource: pts,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(height: 260, child: _buildChart()),
    );
  }
}

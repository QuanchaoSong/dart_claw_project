import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Full-screen chart dialog with zoom / pan / trackball.
/// Open via [ChartFullScreenView.show].
class ChartFullScreenView extends StatefulWidget {
  const ChartFullScreenView({super.key, required this.data});

  final Map<String, dynamic> data;

  static void show(BuildContext context, Map<String, dynamic> data) {
    showDialog<void>(
      context: context,
      builder: (_) => ChartFullScreenView(data: data),
    );
  }

  @override
  State<ChartFullScreenView> createState() => _ChartFullScreenViewState();
}

class _ChartFullScreenViewState extends State<ChartFullScreenView> {
  late final _zoomBehavior = ZoomPanBehavior(
    enablePinching: true,
    enablePanning: true,
    enableDoubleTapZooming: true,
    enableSelectionZooming: true,
    selectionRectBorderWidth: 1.5,
    selectionRectColor: Colors.white10,
  );

  late final _trackball = TrackballBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    lineType: TrackballLineType.vertical,
    lineColor: Colors.white24,
    tooltipSettings: const InteractiveTooltip(
      color: Color(0xFF2C2C2E),
      borderColor: Colors.transparent,
      textStyle: TextStyle(color: Colors.white70, fontSize: 12),
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────────────

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

  // ── Chart builders ──────────────────────────────────────────────────────

  Widget _buildChart() {
    final data = widget.data;
    final type = data['type'] as String? ?? 'line';
    final xLabel = data['x_label'] as String?;
    final yLabel = data['y_label'] as String?;
    final rawSeries = data['series'] as List<dynamic>;

    if (type == 'pie') return _buildPieChart(rawSeries);

    return SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      plotAreaBorderColor: Colors.transparent,
      primaryXAxis: CategoryAxis(
        title: AxisTitle(
          text: xLabel ?? '',
          textStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        majorGridLines: const MajorGridLines(color: Colors.white10),
        axisLine: const AxisLine(color: Colors.white12),
        majorTickLines: const MajorTickLines(color: Colors.white12),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: yLabel ?? '',
          textStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        majorGridLines: const MajorGridLines(color: Colors.white10),
        axisLine: const AxisLine(color: Colors.white12),
        majorTickLines: const MajorTickLines(color: Colors.white12),
      ),
      legend: Legend(
        isVisible: rawSeries.length > 1,
        textStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      zoomPanBehavior: _zoomBehavior,
      trackballBehavior: _trackball,
      series: _buildSeries(type, rawSeries),
    );
  }

  List<CartesianSeries<Map<String, dynamic>, String>> _buildSeries(
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
            markerSettings: const MarkerSettings(height: 10, width: 10),
          ));
        default: // line
          result.add(LineSeries<Map<String, dynamic>, String>(
            name: name,
            dataSource: pts,
            xValueMapper: (pt, _) => pt['x'].toString(),
            yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
            color: color,
            width: 2,
            markerSettings: MarkerSettings(
              isVisible: pts.length <= 30,
              color: color,
              borderWidth: 0,
              height: 7,
              width: 7,
            ),
          ));
      }
    }
    return result;
  }

  Widget _buildPieChart(List<dynamic> rawSeries) {
    final s = rawSeries.first as Map<String, dynamic>;
    final pts = (s['data'] as List<dynamic>)
        .map((pt) => Map<String, dynamic>.from(pt as Map))
        .toList();

    return SfCircularChart(
      backgroundColor: Colors.transparent,
      legend: const Legend(
        isVisible: true,
        textStyle: TextStyle(color: Colors.white54, fontSize: 12),
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: const Color(0xFF2C2C2E),
        textStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      series: [
        PieSeries<Map<String, dynamic>, String>(
          dataSource: pts,
          xValueMapper: (pt, _) => pt['x'].toString(),
          yValueMapper: (pt, _) => (pt['y'] as num).toDouble(),
          pointColorMapper: (_, i) => _seriesColor(i),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          explode: true,
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String?;
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenSize.width - 64,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              // ── Title bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '图表',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Reset zoom hint
                    const Text(
                      '双击重置缩放',
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 16, color: Colors.white38),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // ── Chart ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  child: _buildChart(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

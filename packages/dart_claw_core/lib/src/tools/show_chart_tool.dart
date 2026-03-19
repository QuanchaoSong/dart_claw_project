import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../model/tool_result.dart';
import 'claw_tool.dart';

/// Tells the UI to render a chart in the chat interface.
///
/// The tool validates the incoming JSON structure and, on success, echoes it
/// back inside a `[chart displayed:{...}]` envelope so the UI layer can
/// extract and render it with whatever charting library it prefers.
///
/// Supported chart types: line, bar, area, pie, scatter.
///
/// Expected args shape:
/// ```json
/// {
///   "type": "line",          // required
///   "title": "Sales 2024",   // optional
///   "x_label": "Month",      // optional – axis label for x
///   "y_label": "Amount",     // optional – axis label for y
///   "series": [              // required
///     {
///       "name": "Product A",
///       "data": [
///         {"x": "Jan", "y": 12000},
///         {"x": "Feb", "y": 15000}
///       ]
///     }
///   ]
/// }
/// ```
/// For `pie` charts `x` is the slice label and `y` is its value.
class ShowChartTool implements ClawTool {
  static const _supportedTypes = {
    'line',
    'bar',
    'area',
    'pie',
    'scatter',
  };

  @override
  String get name => 'show_chart';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Render a chart in the chat interface. '
              'Use this when the user asks for a graph, plot, diagram, or visual representation of data. '
              'Supported types: line, bar, area, pie, scatter.',
          'parameters': {
            'type': 'object',
            'properties': {
              'type': {
                'type': 'string',
                'enum': ['line', 'bar', 'area', 'pie', 'scatter'],
                'description': 'The chart type to render.',
              },
              'title': {
                'type': 'string',
                'description': 'Optional chart title shown above the chart.',
              },
              'x_label': {
                'type': 'string',
                'description': 'Optional label for the X axis.',
              },
              'y_label': {
                'type': 'string',
                'description': 'Optional label for the Y axis.',
              },
              'series': {
                'type': 'array',
                'description':
                    'One or more data series. Each series has a name and a list of {x, y} data points. '
                    'For pie charts, x is the slice label and y is its value (number). '
                    'x can be a string or number; y must be a number.',
                'items': {
                  'type': 'object',
                  'properties': {
                    'name': {'type': 'string'},
                    'data': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'properties': {
                          'x': {},
                          'y': {'type': 'number'},
                        },
                        'required': ['x', 'y'],
                      },
                    },
                  },
                  'required': ['name', 'data'],
                },
                'minItems': 1,
              },
            },
            'required': ['type', 'series'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final type = args['type'] as String? ?? '';
    if (!_supportedTypes.contains(type)) {
      return ToolResult.failure(
          '[error] Unsupported chart type: "$type". Use one of: ${_supportedTypes.join(', ')}');
    }

    final series = args['series'];
    if (series is! List || series.isEmpty) {
      return ToolResult.failure('[error] "series" must be a non-empty array');
    }

    // Validate each series entry.
    for (final s in series) {
      if (s is! Map) {
        return ToolResult.failure('[error] Each series entry must be an object');
      }
      final data = s['data'];
      if (data is! List || data.isEmpty) {
        return ToolResult.failure(
            '[error] Each series must have a non-empty "data" array');
      }
      for (final pt in data) {
        if (pt is! Map || !pt.containsKey('x') || !pt.containsKey('y')) {
          return ToolResult.failure(
              '[error] Each data point must have "x" and "y" fields');
        }
        if (pt['y'] is! num) {
          return ToolResult.failure('[error] "y" values must be numbers');
        }
      }
    }

    debugPrint('ShowChartTool: rendering $type chart');

    // Echo the full args back as JSON so the UI can deserialise and render.
    final json = jsonEncode(args);
    return ToolResult.success('[chart displayed:$json]');
  }
}

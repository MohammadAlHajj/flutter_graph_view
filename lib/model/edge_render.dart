import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';


class EdgeRender {
  final Edge edge;

  bool needsUpdate = true;

  double lastTextZoom = 0;

  /// ------ Edge Text Render ------
  String? text;
  TextStyle? textStyle;
  Paragraph? paragraph;



  /// ------ Edge Line Shape Render ------

  /// flag whether colors should be updated every frame. 'false' reduces performance
  bool hasStaticColors = false;
  /// line shape colors if the edge is weak
  List<Color> lineShapeColorsWeaken = [];
  /// line shape colors if the edge is not weak
  List<Color> lineShapeColors = [];
  /// line shape zoom of the last frame
  double lastLineShapeZoom = 0;
  /// line shape zoom of the current frame
  Shader? lastLineShapeShader;
  /// is Weakened flag of the last frame
  bool lastIsWeakened = false;

  EdgeRender(this.edge);

  /// regenerates the colors if they are not already set INSIDE the edge
  bool generateColorsIfNeeded(double strongOpacity, double hoverOpacity) {
    bool generated = false;
    if (lineShapeColorsWeaken.isEmpty || hasStaticColors)
    {
      lineShapeColorsWeaken = List.generate(2, (index) =>
        [
          (edge.start.colors.lastOrNull ?? Colors.white)
              .withValues(alpha: hoverOpacity),
          (edge.end?.colors.lastOrNull ?? Colors.white)
              .withValues(alpha: hoverOpacity)
        ][index],
      );
      generated = true;
    }

    if (lineShapeColors.isEmpty || hasStaticColors)
    {
      lineShapeColors = List.generate(2, (index) =>
        [
          (edge.start.colors.lastOrNull ?? Colors.white)
              .withValues(alpha: strongOpacity),
          (edge.end?.colors.lastOrNull ?? Colors.white)
              .withValues(alpha: strongOpacity),
        ][index],
      );
      generated = true;
    }
    return generated;
  }

}

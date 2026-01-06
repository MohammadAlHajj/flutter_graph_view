// Copyright (c) 2023- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:ui';

import 'package:flutter_graph_view/flutter_graph_view.dart';
import 'package:isolate_manager/isolate_manager.dart';

/// Common tools.
///
/// 常用工具类
class Util {
  /// Compute distance between two point.
  ///
  /// 计算两点间的距离。
  static distance(Vector2 p1, Vector2 p2) {
    return (p1 - p2).length;
  }

  // Type cast.
  @Deprecated('Please use `v?.toOffset()` insteads of')
  static Offset? toOffsetByVector2(Vector2? v) {
    return v == null ? null : Offset(v.x, v.y);
  }
}

abstract class ParallelizableDecorator{
  ComputeRes computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph);
  Map<String,dynamic> serialize({Map<String, dynamic> params = const {}});
  String get isolateFuncWorkerName;
  int get isolateCount;
  void Function(dynamic params) get isolateAttachFunc;
}

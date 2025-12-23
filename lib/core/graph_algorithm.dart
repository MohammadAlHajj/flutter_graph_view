// Copyright (c) 2023- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';


///
/// Interface: point assignment algorithm of graph.
/// 接口：图的点位赋值算法
///
abstract class GraphAlgorithm {
  static final Map<String, GraphAlgorithm Function(Map<String,dynamic>)> _deserializationMap = {};
  static GraphAlgorithm queryAndDeserialize(String type, Map<String,dynamic> params) {
    if(!_deserializationMap.containsKey(type)) {
      throw StateError("A deserialization func with this type:$type is NOT registered."
          " Be sure to use YourGraphAlgorithm.runtimeType.toString() as the deserialization key \nCurrent Map:\n"
          "${_deserializationMap}");
    }
    else {
      return _deserializationMap[type]!(params);
      print("$type queryAndDeserialize successful: $_deserializationMap");
    }
  }
  static registerDeserialization(Type type, GraphAlgorithm Function(Map<String,dynamic>) initFunc){
    if(_deserializationMap.containsKey(type.toString())) {
      throw StateError("A deserialization func with this type:$type is already registered."
          " Be sure to use YourGraphAlgorithm.runtimeType as the deserialization key. \nCurrent Map:\n"
          "${_deserializationMap}");
    }
    else {
      _deserializationMap[type.toString()] = initFunc;
      print("$type added: $_deserializationMap");
    }
  }

  /// In case of serialization, call this method first, then override the items
  /// as you see fit. If you call it later, it might override your entries.
  /// do NOT override "type" value unless you know what you are doing
  @mustCallSuper
  Map<String, dynamic> serialize({Map<String, dynamic> params = const {}}) =>
      {
        "type": runtimeType.toString(),
        "params": params,
        "decorators": decorators?.map((d) => d.serialize()).toList(),
      };



  ///
  /// Algorithm decorate support.
  /// 定位算法的装饰器，可多个算法同时使用。
  ///
  List<GraphAlgorithm>? decorators;

  GraphAlgorithm? rootAlg;

  Widget Function()? horizontalOverlay;
  Widget Function()? verticalOverlay;
  Widget Function()? leftOverlay;
  Graph? graph;

  List<Widget>? horizontalOverlays({
    required GraphAlgorithm rootAlg,
    required Graph graph,
  }) {
    return [
      if (horizontalOverlay != null) horizontalOverlay!(),
      if (decorators != null)
        ...decorators!
            .where((alg) => alg.horizontalOverlay != null)
            .map((ob) => ob.horizontalOverlay!())
            .toList(),
    ];
  }

  void hideVerticalOverlay() {
    graph?.options?.hideVerticalPanel();
  }

  void hideHorizontalOverlay() {
    graph?.options?.hideHorizontalOverlay();
  }

  void hideVertexTapUpOverlay() {
    graph?.options?.hideVertexTapUpPanel();
  }

  List<Widget>? verticalOverlays({
    required GraphAlgorithm rootAlg,
    required Graph graph,
  }) {
    return [
      if (verticalOverlay != null) verticalOverlay!(),
      if (decorators != null)
        ...decorators!
            .where((alg) => alg.verticalOverlay != null)
            .map((ob) => ob.verticalOverlay!())
            .toList(),
    ];
  }

  List<Widget>? leftOverlays({
    required GraphAlgorithm rootAlg,
    required Graph graph,
  }) {
    return [
      if (leftOverlay != null) leftOverlay!(),
      if (decorators != null)
        ...decorators!
            .where((alg) => alg.leftOverlay != null)
            .map((ob) => ob.leftOverlay!())
            .toList(),
    ];
  }

  setGlobalData({
    required GraphAlgorithm rootAlg,
    required Graph graph,
  }) {
    this.rootAlg = rootAlg;
    this.graph = graph;
    decorators?.forEach((element) {
      element.setGlobalData(rootAlg: rootAlg, graph: graph);
    });
  }

  ///
  ///
  GraphAlgorithm({this.decorators});

  /// Notify the size change event.
  ///
  /// 植入对容器尺寸的监听，用于捕捉窗口变化对画布产生的影响
  ValueNotifier<Size?> $size = ValueNotifier(null);

  ///
  /// Stage size.
  /// 图形展示的区域边界
  ///
  Size? get size => $size.value;

  /// Center of stage.
  /// 图形展示的中心点
  Offset get center => Offset((size?.width ?? 0) / 2, (size?.height ?? 0) / 2);

  @mustCallSuper
  void afterDrag(Vertex vertex, Vector2 globalDelta) {
    for (GraphAlgorithm decorator in decorators ?? []) {
      decorator.afterDrag(vertex, globalDelta);
    }
  }

  @mustCallSuper
  void beforeMerge(dynamic data) {
    for (GraphAlgorithm decorator in decorators ?? []) {
      decorator.beforeMerge(data);
    }
  }

  @mustCallSuper
  void beforeLoad(data) {
    for (GraphAlgorithm decorator in decorators ?? []) {
      decorator.beforeLoad(data);
    }
  }

  void onGraphLoad(Graph graph) {
    beforeLoad(graph.data);
    for (var v in graph.vertexes) {
      onLoad(v);
    }
  }

  /// Nodes zoom offset from center.
  /// 节点区域相对中心点的偏移量。
  double get offset => min(center.dx, center.dy) * 0.4;

  /// Position setter.
  ///
  /// 对节点进行定位设值
  @mustCallSuper
  void compute(Vertex v, Graph graph) {
    if (decorators != null) {
      for (var decorator in decorators!) {
        if (!decorator.needContinue(v)) return;
        decorator.compute(v, graph);
      }
    }
  }

  @mustCallSuper
  ComputeRes computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph) {
    final forcePerVertexMap = ComputeRes();
    // for (var v in vertexList) {
    //   forcePerVertexMap[v["id"] as String] = Vector2.zero();
    // }
    if (decorators != null) {
      for (var decorator in decorators!) {
        // if (!decorator.needContinueRaw(vertex)) return;
        final perDecoratorForceMap = decorator.computeRaw(vertexList, graph);
        for (final keys in perDecoratorForceMap.keys){
          forcePerVertexMap[keys] = forcePerVertexMap.containsKey(keys)
              ? forcePerVertexMap[keys] + perDecoratorForceMap[keys]!
              : perDecoratorForceMap[keys]!;
        }
      }
    }
    return forcePerVertexMap;
  }

  bool needContinue(Vertex v) {
    return true;
  }

  bool needContinueRaw(Map vertex) => vertex["needContinue"] as bool? ?? true;


  /// Called when the graph is loaded.
  @mustCallSuper
  void onLoad(Vertex v) {
    if (decorators != null) {
      for (var decorator in decorators!) {
        decorator.onLoad(v);
      }
    }
  }

  void onDrag(Vertex? hoverVertex, Vector2 globalDelta) {
    if (hoverVertex == null) return;
    var zoom = graph?.options?.scale.value ?? 1;
    var delta = globalDelta / zoom;
    hoverVertex.position += delta;
    for (var neighbor in hoverVertex.neighbors) {
      if (neighbor.degree < hoverVertex.degree) {
        neighbor.position += delta;
      }
    }
    afterDrag(hoverVertex, globalDelta);
  }

  void onZoomEdge(Edge edge, Vector2 pointLocation, double delta) {}
}

// class ComputeKey{
//   String source,target;
//
//   ComputeKey({required this.source,required this.target});
// }

// class ComputeVal{
//   Vector2? force;
//   Vector2? position;
//   bool overridePos;
//
//   ComputeVal({this.force, this.position, this.overridePos = false});
//
//   ComputeVal operator +(ComputeVal? other) {
//     if(other == null) {
//       return this;
//     }
//     if(other.overridePos){
//       return other;
//     }
//     if(overridePos){
//       return this;
//     }
//     return ComputeVal(
//       force: force + other.force,
//       position: position + other.position
//     );
//   }
// }



// Copyright (c) 2024- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';

/// Construct a decorative device with spring force between connected nodes.
///
/// 在相连节点间构建弹簧力的装饰器。
class HookeDecorator extends ForceDecorator {
  double length;
  double k;
  double Function(double length, int degree)? degreeFactor;

  /// register type deserializer in GraphAlgorithm
  static final _ =  GraphAlgorithm.registerDeserialization(HookeDecorator, deserialize);
  static HookeDecorator deserialize(Map params) =>
      HookeDecorator(
        length: double.parse(params["length"] as String),
        k: double.parse(params["k"] as String),
        sameTagsFactor: double.parse(params["sameTagsFactor"] as String),
        // degreeFactor: params["degreeFactor"] as String),
      );

  @override
  Map<String, dynamic> serialize({Map<String, dynamic> params = const {}}) {
    return super.serialize(params: {
      "k": k.toString(),
      "length": length.toString(),
      "sameTagsFactor": sameTagsFactor.toString(),
    });
  }


  @override
  Widget Function()? get verticalOverlay =>
      handleOverlay != null ? () => handleOverlay!(this) : null;

  Widget Function(HookeDecorator)? handleOverlay;

  HookeDecorator({
    this.length = 100,
    this.k = 0.003,
    super.sameTagsFactor = 1,
    this.handleOverlay,
    this.degreeFactor,
  }){
    var _ = HookeDecorator._;
    // print("Called: HookeDecorator constructor");

  }

  Vector2 hooke(Vertex s, Vertex d, Graph graph) {
    var len = degreeFactor?.call(length, d.neighborEdges.length) ?? length;
    var delta = s.position - d.position;
    var distance = delta.length;
    var force = -(distance - len - log(s.degree + d.degree)) * k;
    return delta * force;
  }

  Vector2 hookeRaw(Map<String, dynamic> s, Map<String, dynamic> d, Map<String, dynamic> graph) {
    // var len = degreeFactor?.call(length, d.neighborEdges.length) ?? length;
    var len = length;
    var delta = s["position"] - d["position"];
    var distance = delta.length;
    var force = -(distance - len - log(s["degree"] + d["degree"])) * k;
    return delta * force;
  }

  @override
  // ignore: must_call_super
  void compute(Vertex v, Graph graph) {
    for (var n in v.neighbors) {
      if (v.position != Vector2.zero() && n.position != Vector2.zero()) {
        var force = hooke(v, n, graph);
        setForceMap(v, n, force);
      }
    }
  }

  @override
  ComputeRes computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph) {
    final perVertexCalcMap = ComputeRes();
    // for (final v in vertexList) {
    //   perVertexCalcMap[v["id"] as String] = Vector2.zero();
    // }

    for (final v in vertexList) {
      for (var n in v["neighbors"]) {
        if (v["position"] != Vector2.zero() && n["position"] != Vector2.zero()) {
          perVertexCalcMap[(v["id"], n["id"])]
            = hookeRaw(v, n, graph);
        }
      }
    }
    final childForces = super.computeRaw(vertexList, graph);
    for (final keys in perVertexCalcMap.keys){
      childForces[keys] = childForces.containsKey(keys)
        ? childForces[keys] + perVertexCalcMap[keys]!
        : perVertexCalcMap[keys]!;
    }
    return perVertexCalcMap;
  }
}

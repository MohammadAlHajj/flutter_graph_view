// Copyright (c) 2024- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:math';

import 'package:flutter_graph_view/flutter_graph_view.dart';

/// Decorators in which all nodes in the figure form repulsive interactions with each other.
///
/// 图中所有节点相互间形成排斥的装饰器（库仑力）
class CoulombDecorator extends ForceDecorator {
  double k;

  /// register type deserializer in GraphAlgorithm
  static final _ =  GraphAlgorithm.registerDeserialization(CoulombDecorator, deserialize);
  static CoulombDecorator deserialize(Map params) =>
      CoulombDecorator(
          k: double.parse(params["k"] as String),
          sameTagsFactor: double.parse(params["sameTagsFactor"] as String),
      );

  @override
  Map<String, dynamic> serialize({Map<String, dynamic> params = const {}}) {
    return super.serialize(params: {
      "k": k.toString(),
      "sameTagsFactor": sameTagsFactor.toString(),
    });
  }



  CoulombDecorator({this.k = 10, super.sameTagsFactor = 1}){
    var _ = CoulombDecorator._;
    // print("Called: CoulombDecorator constructor");
  }


  @override
  // ignore: must_call_super
  void compute(Vertex v, Graph graph) {
    for (var b in graph.vertexes) {
      if (v != b &&
          v.position != Vector2.zero() &&
          b.position != Vector2.zero()) {
        // F = k * q1 * q2 / r^2
        var delta = v.position - b.position;
        var distance = delta.length;
        var force = k * v.radius * b.radius / max((distance * distance), 1);
        var f = delta * force;
        setForceMap(v, b, f);
      }
    }
  }

  @override
  Map<String, Vector2> computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph) {
    final forcePerVertexMap = <String, Vector2>{};
    for (final v in vertexList) {
      forcePerVertexMap[v["id"] as String] = Vector2.zero();
    }

    for (final v in vertexList) {
      for (var gv in graph["vertexes"]) {
        Vector2 vPos = v["position"];
        Vector2 gvPos = gv["position"];
        if (
          v["id"] !=gv["id"] &&
          vPos != Vector2.zero() &&
          gvPos != Vector2.zero()
        ) {
          // F = k * q1 * q2 / r^2
          var delta = vPos - gvPos;
          var distance = delta.length;
          var force = k * v["radius"] * gv["radius"] / max((distance * distance), 1);

          forcePerVertexMap[v["id"] as String] = delta * force;
        }
      }
    }

    final childForces = super.computeRaw(vertexList, graph);
    for (final key in childForces.keys){
      forcePerVertexMap[key] = forcePerVertexMap[key]! + childForces[key]!;
    }
    return forcePerVertexMap;
  }
}

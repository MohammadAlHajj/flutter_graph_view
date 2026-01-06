import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';
import 'package:intl/intl.dart';

/// A Decorator that translates the calculated forces on graph vertexes into 
/// motion. This decorator reads and updates vertex velocity while damping it.
/// You can think of damping as friction on a moving car; if no force (acceleration) is
/// applied on the car, it will eventually stop. This decorator also scales down
/// the effects of new forces with each graph cycle. This gets rid of
/// oscillation when the graph doesn't naturally converge, or is too complex to
/// reach convergence on its own (google "three body problem")
class DampenedForceMotionDecorator extends ForceMotionDecorator {
  /// velocity damping factor per cycle (e.g. 0.90)
  double damping;
  /// velocity scale on new forces
  double _scaling;
  /// minimum timestep to cool down to
  double minTimestep;
  /// multiply [_scaling] by this each cycle (cooling)
  double coolingFactor;
  /// threshold for max movement (px) to consider the graph as converged
  double stopTolerance;
  /// number of graph cycles with max of the per-vertex movements is below
  /// [stopTolerance] before stopping
  int stableCyclesThreshold;
  /// IDs of vertices to pin (freeze)
  Set<dynamic> pinnedVertexIds;

  // Internal state
  /// how many Graph Cycles has the vertexes not moved above the [stopTolerance]
  /// look at [stableCyclesThreshold]
  int stableCycleCount = 0;
  /// the max movement any vertex did this graph cycle
  double _maxMove = double.negativeInfinity;

  DampenedForceMotionDecorator({
    this.damping = 0.98,
    double initialTimestep = 1.0,
    this.minTimestep = 0.02,
    this.coolingFactor = 0.997,
    this.stopTolerance = 5.0,
    this.stableCyclesThreshold = 30, //
    Set<dynamic>? pinned,
  }) : 
        pinnedVertexIds = pinned ?? {}, 
        _scaling=initialTimestep;


  bool firstRun = true;
  static DateTime timestamp = DateTime.now();


  @override
  // ignore: must_call_super
  void compute(Vertex v, Graph graph) {

    /// used for logging the time it took for the graph to reach stability
    if (kDebugMode) {
      if (firstRun) {
        timestamp = DateTime.now();
        firstRun = false;
      }
    }
    if (pinnedVertexIds.contains(v.id)) {
      // Freeze pinned vertex: zero out force and velocity, skip position update
      v.velocity = Vector2.zero();
      return;
    }
    if (v == graph.hoverVertex) {
      return;
    }

    // Apply damping to existing velocity
    v.velocity *= damping;
    // Update velocity by acceleration (force).
    // v.velocity += v.force * timestep;
    var a = v.force / v.radius;
    // var a = v.force;

    // Vector2 absForce = a.clone()..absolute();
    v.velocity += (a - v.velocity) * _scaling;
    // v.velocity.clamp(-absForce, absForce);
    // Update position by velocity
    final oldPos = v.position.clone();
    v.position += v.velocity * _scaling;
    // Track max movement (distance moved this frame)
    // final moveDist = (v.vx * timestep).abs().clamp((v.vy * timestep).abs(), double.infinity);

    // update biggest position change to use in stability check
    final moveDist = (v.position - oldPos).length;
    if (moveDist > _maxMove) _maxMove = moveDist;

    // execute the below only once per graph cycle
    if(graph.vertexes.isEmpty || v != graph.vertexes.last ){
      return;
    }

    if (kDebugMode) {
      print("----------Max move this graph cycle: $_maxMove");
    }


    if (_scaling > minTimestep) {
      _scaling *= coolingFactor;
      if (_scaling < minTimestep) _scaling = minTimestep;
    }
    // Check for stability (no significant movement)
    if (_maxMove < stopTolerance) {
      stableCycleCount++;
    } else {
      stableCycleCount = 0;
    }
    // If stable for many frames, signal a stop
    // if (stableCycleCount > stableFramesThreshold) {
    //   // Mark graph as converged (reached its final position).
    //   graph.options?.pause.value = true;
    //   if (kDebugMode) {
    //     print("----------Cooldown time: ${
    //         NumberFormat('#,##0.00').format(DateTime.now().difference(timestamp).inMicroseconds / 1000.0)
    //     }");
    //   }
    // }

    // reset max distance moved for this graph cycle
    _maxMove = double.negativeInfinity;
  }

}

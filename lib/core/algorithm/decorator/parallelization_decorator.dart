import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';
import 'package:intl/intl.dart';
import 'package:isolate_manager/isolate_manager.dart';

@pragma('vm:entry-point')
@isolateManagerCustomWorker
void longRunningComplexCalculation(dynamic params) {
  IsolateManagerFunction.customFunction<Map<String, Vector2>, Map<String, dynamic>>(
    params,
    onEvent: (controller, jsonInput) {
      CoulombDecorator();
      HookeDecorator();
      CoulombBorderDecorator();
      ParallelizationDecorator rootDec = ParallelizationDecorator.deserialize(jsonInput["decorator"]);
      // controller.sendResult(
          return rootDec.computeRaw(jsonInput["vertex"], jsonInput["graph"]);
      // );
      // // Send the final result
    },
    // onInit: (controller) {
    //   print('Custom Fibonacci Worker: Initialized');
    //   // Perform any setup logic here
    // },
    // onDispose: (controller) {
    //   print('Custom Fibonacci Worker: Disposed');
    //   // Perform any cleanup logic here
    // },
    autoHandleException: true, // Set to true to let IsolateManager handle basic errors
    autoHandleResult: true,    // Set to true to let IsolateManager handle basic result sending
  );
}

/// A GraphAlgorithm that runs force-directed layout in a background isolate.
class ParallelizationDecorator extends ForceDecorator {
  final List<Vertex> _vertexList = []; // local reference to vertices for quick position update
  late IsolateManager<Map<String, Vector2>, Map<String, dynamic>> _singleFuncIsolate;

  var currFrame = 0;
  static int batchSize = 10;
  int processedSize = 0;

  static DateTime timestamp = DateTime.now();

  /// register type deserializer in GraphAlgorithm
  static final _ =  GraphAlgorithm.registerDeserialization(ParallelizationDecorator, deserialize);
  static ParallelizationDecorator deserialize(Map<String,dynamic> params) =>
      ParallelizationDecorator()..decorators =
          (params["decorators"] as List<Map>).map<GraphAlgorithm>(
              (Map d) => GraphAlgorithm.queryAndDeserialize(
                  d["type"] as String,
                  d["params"] ?? <String,dynamic>{})
          ).toList();

  @pragma('vm:entry-point')
  @isolateManagerWorker
  Map<String, dynamic> complexCalculation(
      Map<String, dynamic> jsonInput
  ) {
    // Simulate a task that might send progress updates or run for a while
    // final jsonDecode(jsonAlgSerialized);
    ParallelizationDecorator rootDec = deserialize(jsonInput["decorator"]);
    return rootDec.computeRaw(jsonInput["vertex"], jsonInput["graph"]);
  }


  ParallelizationDecorator({super.decorators, int? batchSize})
  {
    print("batchSize is null: $batchSize");
    ParallelizationDecorator.batchSize = batchSize ?? ParallelizationDecorator.batchSize;
    ParallelizationDecorator._;

    // No heavy initialization here. Actual isolate spawn happens in onGraphLoad.
    // We do NOT pass decorators to the base class, to avoid main-thread execution.
  }



  // /// Assign initial random positions to each vertex during graph loading.
  // @override
  // void onLoad(Vertex v) {
  //   // For example: place within a circle of radius R around (0,0) or center.
  //   final R = 200.0;
  //   final angle = Random().nextDouble() * 2 * pi;
  //   final radius = Random().nextDouble() * R;
  //   // If the graph view provides a center or size, one could use that. Here we just scatter around origin.
  //   final dx = cos(angle) * radius;
  //   final dy = sin(angle) * radius;
  //   // Set the vertex position (using the vertex's component or position vector)
  //   v.position = Vector2(dx, dy);  // cpn is the VertexComponent (PositionComponent) if available
  //   // If cpn is null, alternatively: v.position = Vector2(dx, dy) if such property exists.
  // }

  /// Once the entire graph is loaded, spawn the isolate and start the background simulation.
  @override
  void setGlobalData({
    required GraphAlgorithm rootAlg,
    required Graph graph,
  }) async {
    super.setGlobalData(rootAlg: rootAlg, graph: graph);
    // final msg = 'frame_done';
    //   currFrame++;
      // Isolate signaled it finished (optional).
      // We can clean up if needed.

    _singleFuncIsolate = IsolateManager.createCustom(
      longRunningComplexCalculation, // The function this isolate is dedicated to
      workerName: 'longRunningComplexCalculation', // For JS worker
      concurrent: 1, // Typically 1 for a single dedicated function
      isDebug: false, // Enable more logging
      queueStrategy: DropNewestStrategy(maxCount: 10)
    );

    // Optional: Listen for intermediate values
    // _singleFuncIsolate.stream.listen((value) {
    //   if (kDebugMode) {
    //     print('Intermediate value from single-function isolate: $value');
    //   }
    // });

    // print('Complex Calculation Result: $calculationResult');

    // await singleFuncIsolate.stop(); // Release resources
    // Or use `singleFuncIsolate.restart()` to restart the isolate
  }


  /// Apply new positions from the isolate to the local graph vertices.
  void _applyPositions(List<double> positions) {
    assert(positions.length == _vertexList.length * 2);
    for (int i = 0; i < _vertexList.length; i++) {
      final vx = _vertexList[i];
      final x = positions[2 * i], y = positions[2 * i + 1];
      // Update vertex position on main thread
      vx.position = Vector2(x, y);
    }
    // Mark the graph view for repaint if necessary (often the GraphWidget is already ticking).
    // If needed, one could call something like: FlutterGraphWidget.of(context)?.markNeedsPaint();
  }


  // bool _busy = false;
  // bool _ready = false;
  // bool _firstTime = true;
  // String _firstVertexId = "";
  /// No-op compute on main thread – the heavy work is done in the isolate.
  @override
  /// ignore: call parent
  Future<void> compute(Vertex v, Graph graph) async {
    // if (_firstTime){
    //   _firstTime = false;
    //   _firstVertexId = v.id;
    // }

    // if (v.id == _firstTime)
    //
    // print("batchSize: $batchSize");
    if(v.g!.options!.pause.value) {
      return;
    }

    // if(_singleFuncIsolate.queuesLength > 1 && batchSize < graph.vertexes.length) {
    //   batchSize+= 10;
    // }

    batchSize = graph.vertexes.length;

    List<Vertex<dynamic>> tempVertexList;

    _vertexList.add(v);
    if(_vertexList.length < batchSize && graph.vertexes.last.id != v.id) {
      // print("When did i get here $batchSize");
      return;
    } else {
      // print(" ${graph.vertexes.length} $processedSize $batchSize ${_vertexList.length} - ${_singleFuncIsolate.queuesLength}" );
      tempVertexList = _vertexList.toList();
      _vertexList.clear();
      processedSize += _vertexList.length;
    }

    try {
      await _singleFuncIsolate.compute({
        "decorator" : serialize(),
        "vertex" : tempVertexList.map((v) => v.toJson()).toList(),
        "graph" : graph.toJson()
      }, callback: (res) {
        var shortList = graph.vertexes.where((v) => res.containsKey(v.id)).toList();
        res.forEach((key, force) {
          final currVertex = shortList.firstWhere((v) => v.id == key);
          setForceMap(currVertex, currVertex, force);
        });

        print("timestamp diff: ${
          NumberFormat('#,##0.00').format(DateTime.now().difference(timestamp).inMicroseconds / 1000.0)
        }");
        timestamp = DateTime.now();
        currFrame++;
        // processedSize += _vertexList.length;
        // _vertexList.clear();
        return true;
      });

      // final result = await customIsolate.compute(10);
      // print('Custom Fibonacci(10): $result');
      //
      // final resultNegative = await customIsolate.compute(-5); // This will throw
      // print('Custom Fibonacci(-5): $resultNegative');
    } on IsolateException catch (e) {
      print('Caught IsolateException: ${e.error}');
      // print('Stack trace: ${e.stacktrace}');
      await _singleFuncIsolate.stop();
    } catch (e) {
      print('Caught other error: $e');
      await _singleFuncIsolate.stop();
    }




    // Do nothing (or minimal bookkeeping). This runs each frame for each vertex,
    // but we've offloaded calculations, so just return immediately.
    print(currFrame);
  }

  @override
  Map<String, Vector2> computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph) {
     return super.computeRaw(vertexList, graph);
  }



  /// Clean up the isolate when the algorithm (graph) is disposed.
  Future<void> dispose() async {
    try {
      await _singleFuncIsolate.stop();
    } catch (_) {
      // If sending fails, just kill the isolate
    }
    // _isolate?.kill(priority: Isolate.immediate);
  }
}

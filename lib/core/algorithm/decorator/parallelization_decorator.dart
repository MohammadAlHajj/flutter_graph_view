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
  IsolateManagerFunction.customFunction<ComputeRes, Map<String, dynamic>>(
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
  final List<Vertex> _currentBatch = []; // local reference to vertices for quick position update
  late IsolateManager<Map<(String, String), Vector2>, Map<String, dynamic>> _singleFuncIsolate;

  var currFrame = 0;
  static int batchSize = 10;
  int isolateCount;
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
  ComputeRes complexCalculation(
      Map<String, dynamic> jsonInput
  ) {
    // Simulate a task that might send progress updates or run for a while
    // final jsonDecode(jsonAlgSerialized);
    ParallelizationDecorator rootDec = deserialize(jsonInput["decorator"]);
    return rootDec.computeRaw(jsonInput["vertex"], jsonInput["graph"]);
  }


  ParallelizationDecorator({super.decorators, this.isolateCount = 2, int? batchSize})
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
    assert(positions.length == _currentBatch.length * 2);
    for (int i = 0; i < _currentBatch.length; i++) {
      final vx = _currentBatch[i];
      final x = positions[2 * i], y = positions[2 * i + 1];
      // Update vertex position on main thread
      vx.position = Vector2(x, y);
    }
    // Mark the graph view for repaint if necessary (often the GraphWidget is already ticking).
    // If needed, one could call something like: FlutterGraphWidget.of(context)?.markNeedsPaint();
  }


  ParallelCalcRes<(String,String), Vector2>? parallelCalcRes;
  List<Vertex> _processedVertexes = [];
  /// No-op compute on main thread – the heavy work is done in the isolate.
  @override
  /// ignore: call parent
  Future<void> compute(Vertex v, Graph graph) async {
    // print("batchSize: $batchSize");
    if(v.g!.options!.pause.value) {
      return;
    }

    // if(_singleFuncIsolate.queuesLength > 1 && batchSize < graph.vertexes.length) {
    //   batchSize+= 10;
    // }

    batchSize = (graph.vertexes.length/isolateCount).ceil();

    List<Vertex<dynamic>> tempVertexList;

    _currentBatch.add(v);
    _processedVertexes.add(v);

    var currBatchIndex = (_processedVertexes.length / batchSize).ceil();
    // if the current batch is not filled, do not do any processing
    if(
      (currBatchIndex < isolateCount && _currentBatch.length < batchSize) ||
      (_processedVertexes.length != graph.vertexes.length)
    ) {
      // print("When did i get here $batchSize");
      return;
    }

    if(_processedVertexes.length == graph.vertexes.length){
      _processedVertexes.clear();
    }


    // print(" ${graph.vertexes.length} $processedSize $batchSize ${_vertexList.length} - ${_singleFuncIsolate.queuesLength}" );
    // create a copy of the current batch to be able to clear it
    tempVertexList = _currentBatch.toList();
    _currentBatch.clear();
    // processedSize += _vertexList.length;
    parallelCalcRes ??= ParallelCalcRes(isolateCount: isolateCount);

    //
    try {
      if(parallelCalcRes!.canProcess){
        var singleCalc = parallelCalcRes!.addSingleCalc();

        var singleCalcStartTime = DateTime.now();

        await _singleFuncIsolate.compute({
          "decorator" : serialize(),
          "vertex" : tempVertexList.map((v) => v.toJson()).toList(),
          "graph" : graph.toJson()
        }, callback: (res) {
          parallelCalcRes!.processRes(res, singleCalc);
          print("single calc time: ${
            NumberFormat('#,##0.00').format(DateTime.now().difference(singleCalcStartTime).inMicroseconds / 1000.0)
          }");

          if(parallelCalcRes!.readyToDisplay){
            var vertexMap = <String, Vertex>{};
            for (var v in v.g!.vertexes) {
              vertexMap[v.id] = v;
            }

            parallelCalcRes!.accruedRes.forEach((keys, force) {
              setForceMap(vertexMap[keys.$1]!, vertexMap[keys.$2]!, force);
            });

            print("----------Frame: $currFrame - parallel calc time: ${
              NumberFormat('#,##0.00').format(DateTime.now().difference(timestamp).inMicroseconds / 1000.0)
            }");
            currFrame++;
            timestamp = DateTime.now();
            // processedSize += _vertexList.length;
            // _vertexList.clear();
            parallelCalcRes!.reset();
          }
          return true;
        });
      }
      // final result = await customIsolate.compute(10);
      // print('Custom Fibonacci(10): $result');
      //
      // final resultNegative = await customIsolate.compute(-5); // This will throw
      // print('Custom Fibonacci(-5): $resultNegative');
    } on IsolateException catch (e) {
      v.g!.options!.pause.value = true;
      print('Caught IsolateException: ${e.error}');
      // print('Stack trace: ${e.stacktrace}');
      await _singleFuncIsolate.stop();
    } catch (e, st) {
      v.g!.options!.pause.value = true;
      print('Caught other error: $e \n $st');
      await _singleFuncIsolate.stop();
    }




    // Do nothing (or minimal bookkeeping). This runs each frame for each vertex,
    // but we've offloaded calculations, so just return immediately.
    print(currFrame);
  }

  @override
  ComputeRes computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph) {
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


class ParallelCalcRes<T, K>{
  int isolateCount;
  List<bool> doneList = [];
  Map<T, K> accruedRes = {};


  ParallelCalcRes({required this.isolateCount});

  /// all calculations are created and calculated
  get readyToDisplay =>
      doneList.length == isolateCount &&
      doneList.every((isDone) => isDone);

  get canProcess => doneList.length < isolateCount;

  processRes(Map<T, K> resMap, int calcIndex){
    doneList[calcIndex] = true;
    accruedRes.addAll(resMap);
  }

  int addSingleCalc(){
    doneList.add(false);
    // return index of new calculation "done" status
    return doneList.length-1;
  }

  reset(){
    doneList =[];
    accruedRes = {};
  }
}

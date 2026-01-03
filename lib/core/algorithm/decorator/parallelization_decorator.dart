import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_graph_view/core/util.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';
import 'package:intl/intl.dart';
import 'package:isolate_manager/isolate_manager.dart';
//
// @pragma('vm:entry-point')
// @isolateManagerCustomWorker
// void longRunningComplexCalculation(dynamic params) {
//   IsolateManagerFunction.customFunction<ComputeRes, Map<String, dynamic>>(
//     params,
//     onEvent: (controller, jsonInput) {
//       CoulombDecorator();
//       HookeDecorator();
//       CoulombBorderDecorator();
//
//       ParallelizationDecorator rootDec = ParallelizationDecorator.deserialize(jsonInput["decorator"]);
//       // controller.sendResult(
//           return rootDec.computeRaw(jsonInput["vertex"], jsonInput["graph"]);
//       // );
//       // // Send the final result
//     },
//     // onInit: (controller) {
//     //   print('Custom Fibonacci Worker: Initialized');
//     //   // Perform any setup logic here
//     // },
//     // onDispose: (controller) {
//     //   print('Custom Fibonacci Worker: Disposed');
//     //   // Perform any cleanup logic here
//     // },
//     autoHandleException: true, // Set to true to let IsolateManager handle basic errors
//     autoHandleResult: true,    // Set to true to let IsolateManager handle basic result sending
//   );
// }

/// A GraphAlgorithm that runs force-directed layout in a background isolate.
class ParallelizationDecorator extends ForceDecorator {
  final List<IsolateManager<ComputeRes, Map<String, dynamic>>> _isolateManagers
    = [];

  var currFrame = 0;
  int isolateCount = -1;

  static DateTime timestamp = DateTime.now();

  List<ParallelizableDecorator> pDecorators;

  @override
  List<GraphAlgorithm> get decorators => pDecorators.map(
      (d) => d as GraphAlgorithm
  ).toList();

  final _isoDecoMap = <IsolateManager, ParallelizableDecorator>{};

  /// register type deserializer in GraphAlgorithm
  // static final _ =  GraphAlgorithm.registerDeserialization(ParallelizationDecorator, deserialize);
  // static ParallelizationDecorator deserialize(Map<String,dynamic> params) =>
  //     ParallelizationDecorator()..decorators =
  //         (params["decorators"] as List<Map>).map<GraphAlgorithm>(
  //             (Map d) => GraphAlgorithm.queryAndDeserialize(
  //                 d["type"] as String,
  //                 d["params"] ?? <String,dynamic>{})
  //         ).toList();

  // @pragma('vm:entry-point')
  // @isolateManagerWorker
  // ComputeRes complexCalculation(
  //     Map<String, dynamic> jsonInput
  // ) {
  //   // Simulate a task that might send progress updates or run for a while
  //   // final jsonDecode(jsonAlgSerialized);
  //   ParallelizationDecorator rootDec = deserialize(jsonInput["decorator"]);
  //   return rootDec.computeRaw(jsonInput["vertex"], jsonInput["graph"]);
  // }


  ParallelizationDecorator({this.pDecorators = const []})
  {
    // ParallelizationDecorator._;


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

    // decorators.
    for (var iso in _isolateManagers) {
      await iso.stop();
    }
    _isolateManagers.clear();
    _isoDecoMap.clear();
    for (var pd in pDecorators) {
      IsolateManager<ComputeRes, Map<String, dynamic>> iso =
        IsolateManager.createCustom(
          pd.isolateAttachFunc, // The function this isolate is dedicated to
          workerName: pd.isolateFuncWorkerName, // For JS worker
          concurrent: 1, // Typically 1 for a single dedicated function
          isDebug: false, // for more logging
          queueStrategy: RejectIncomingStrategy(maxCount: 10)
        );
      _isolateManagers.add(iso);
      _isoDecoMap[iso] = pd;
    }

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



  ParallelCalc<String, Vector2>? parallelCalcRes;
  /// No-op compute on main thread – the heavy work is done in the isolate.
  @override
  /// ignore: call parent
  Future<void> compute(Vertex _, Graph graph) async {
    // print("batchSize: $batchSize");
    if(graph.options!.pause.value) {
      return;
    }

    parallelCalcRes ??= ParallelCalc(isolateCount: pDecorators.length);

    //
    try {
      if(parallelCalcRes!.canProcess){
        for (var iso in _isolateManagers) {
          var index = parallelCalcRes!.addSingleCalc();
          var singleCalcStartTime = DateTime.now();

          iso.compute({
            "decorator" : _isoDecoMap[iso]!.serialize(),
            // "vertex" : tempVertexList.map((v) => v.toJson()).toList(),
            "graph" : graph.toJson()
          }, callback: (res) {
            parallelCalcRes!.processRes(index, res);
            print("single calc time (${_isoDecoMap[iso]!.runtimeType}): ${
                NumberFormat('#,##0.00').format(DateTime.now().difference(singleCalcStartTime).inMicroseconds / 1000.0)
            }");

            if(parallelCalcRes!.readyToDisplay){
              var vMap = graph.vertexByIdMap;

              // accumulate forces
              Map<String, Vector2> totalForcePerVertex = {};
              for (var resMap in parallelCalcRes!.accruedRes) {
                for (var res in resMap.entries) {
                  totalForcePerVertex.addOrSet(res.key, res.value);
                }
              }

              // apply forces
              totalForcePerVertex.forEach((key, force) {
                setForceMap(vMap[key]!, vMap[key]!, force);
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
        }

      // final result = await customIsolate.compute(10);
      // print('Custom Fibonacci(10): $result');
      //
      // final resultNegative = await customIsolate.compute(-5); // This will throw
      // print('Custom Fibonacci(-5): $resultNegative');
    } on IsolateException catch (e, st) {
      graph.options!.pause.value = true;
      print('Caught IsolateException: ${e.error} \n $st');
      // print('Stack trace: ${e.stacktrace}');
      for (var iso in _isolateManagers) {
        await iso.stop();
      }
    } catch (e, st) {
      graph.options!.pause.value = true;
      print('Caught other error: $e \n $st');
      for (var iso in _isolateManagers) {
        await iso.stop();
      }
    }




    // Do nothing (or minimal bookkeeping). This runs each frame for each vertex,
    // but we've offloaded calculations, so just return immediately.
    // print(currFrame);
  }

  @override
  ComputeRes computeRaw(List<Map<String, dynamic>> vertexList, Map<String, dynamic> graph) {
     return super.computeRaw(vertexList, graph);
  }



  /// Clean up the isolate when the algorithm (graph) is disposed.
  Future<void> dispose() async {
    try {
      for (var iso in _isolateManagers) {
        await iso.stop();
      }
    } catch (_) {
      // If sending fails, just kill the isolate
    }
    // _isolate?.kill(priority: Isolate.immediate);
  }
}



class ParallelCalc<T, K>{
  int isolateCount;
  List<bool> doneList = [];
  List<Map<T, K>> accruedRes = [];


  ParallelCalc({required this.isolateCount});

  /// all calculations are created and calculated
  get readyToDisplay =>
      doneList.length == isolateCount &&
      doneList.every((isDone) => isDone);

  get canProcess => doneList.length < isolateCount;

  processRes(int calcIndex, Map<T, K> resMap){
    doneList[calcIndex] = true;
    accruedRes.add(resMap);
  }

  int addSingleCalc(){
    doneList.add(false);
    // return index of new calculation "done" status
    return doneList.length-1;
  }

  reset(){
    doneList =[];
    accruedRes = [];
  }
}

// parallelization_decorator.

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

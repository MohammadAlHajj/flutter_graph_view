// Copyright (c) 2025- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:ui' as ui;

import 'package:vector_math/vector_math.dart' show Vector2;

extension SizeExt on ui.Size {
  Vector2 toVector2() => Vector2(width, height);
  ui.Offset toOffset() => ui.Offset(width, height);
}

extension Vector2Ext on Vector2 {
  ui.Offset toOffset() => ui.Offset(x, y);

  Vector2 operator +(Vector2? other) =>
      other == null ? this : this + other
  ;
}

extension OffsetExt on ui.Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}

extension Vector2ExtNullible on Vector2? {
  Vector2 operator +(Vector2? other) =>
    this == null
        ? (other ?? Vector2.zero())
        : (other == null ? this! : this! + other)
    ;
}

typedef ComputeRes = Map<(String,String), Vector2>;
// ///
// /// $1: force
// /// $2: position
// /// $3 override position: the position should be taken directly and force should
// ///   be ignored
// extension ComputeValNullable on ComputeVal? {
//   ComputeVal operator +(ComputeVal? other) {
//     if (this == null){
//       return (Vector2.zero(), Vector2.zero(), false);
//     }
//
//     if(other == null) {
//       return this!;
//     }
//     if(other.$3){
//       return other;
//     }
//     if(this!.$3){
//       return this!;
//     }
//     return (
//       this!.$1 + other.$1,
//       this!.$2 + other.$2,
//       false
//     );
//   }
// }
// Copyright (c) 2023- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';

/// Randomly generate node positions in the field of view during loading
///
/// 在加载时，在视野中随机生成节点的位置
class HashedPositionAlgorithm extends RandomAlgorithm {
  HashedPositionAlgorithm({super.decorators});

  @override
  void onLoad(Vertex v) {
    if (v.position == Vector2(0, 0)) {
      var bounds = graph?.options?.visibleWorldRect ??
          const Rect.fromLTWH(0, 0, 1920, 1080);
      final pos = hashedPositionInRect(v.id.toString(), bounds);
      // v.position = Vector2(math.Random().nextDouble() * (bounds.width - 50) + 25,
      //     math.Random().nextDouble() * (bounds.height - 50) + 25);
      v.position = pos;
    }
    super.onLoad(v);
  }

  /// Returns a deterministic "random" position inside [bounds] derived from [id].
  ///
  /// - Same [id] + same [bounds] => same result (repeatable).
  /// - Different ids tend to spread out well.
  /// - Uses a stable 64-bit FNV-1a hash (platform-independent).
  Vector2 hashedPositionInRect(String id, Rect bounds) {
    if (bounds.width <= 0 || bounds.height <= 0) {
      return Vector2(bounds.left, bounds.top);
    }

    final h = _fnv1a64(id);

    // Split into two 32-bit values for x/y.
    final hx = (h & 0xFFFFFFFF);
    final hy = (h >> 32) & 0xFFFFFFFF;

    // Map to [0,1) with 32-bit precision.
    final ux = hx / 4294967296.0; // 2^32
    final uy = hy / 4294967296.0;

    final x = bounds.left + ux * bounds.width;
    final y = bounds.top + uy * bounds.height;
    return Vector2(x, y);
  }

  /// 64-bit FNV-1a hash over UTF-16 code units (Dart String representation).
  int _fnv1a64(String s) {
    const int fnvOffset = 0xcbf29ce484222325; // 14695981039346656037
    const int fnvPrime = 0x100000001b3;       // 1099511628211
    const int mask64 = 0xFFFFFFFFFFFFFFFF;

    var hash = fnvOffset;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * fnvPrime) & mask64;
    }
    return hash;
  }
}

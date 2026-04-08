// Copyright (c) 2024- All flutter_graph_view authors. All rights reserved.
//
// This source code is licensed under Apache 2.0 License.

import 'package:flutter_graph_view/flutter_graph_view.dart';

class PinToCenterDecorator extends ForceDecorator {
  final Set<dynamic> pinned;
  PinToCenterDecorator({this.pinned = const {}});

  @override
  bool needContinue(Vertex v) {
    if (pinned.contains(v.id)) {
      return false;
    } else {
      return true;
    }
  }

  void addPinned(dynamic id) {
    pinned.add(id);
  }


  @override
  // ignore: must_call_super
  void compute(Vertex v, Graph graph) {
    if (pinned.contains(v.id)) {
      v.position = Vector2.zero();
      v.force = Vector2.zero();
    }
  }
}

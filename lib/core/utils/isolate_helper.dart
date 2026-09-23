import 'dart:async';
import 'dart:isolate';

/// Helper to execute computationally heavy work in background isolates.
class IsolateHelper {
  /// Runs a top-level or static function [computation] with argument [message] in a worker isolate.
  static Future<R> run<M, R>(FutureOr<R> Function(M message) computation, M message) {
    return Isolate.run<R>(() => computation(message));
  }
}

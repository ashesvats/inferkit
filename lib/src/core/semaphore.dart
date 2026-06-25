import 'dart:async';
import 'dart:collection';

class Semaphore {
  Semaphore(this.maxConcurrent) {
    if (maxConcurrent < 1) {
      throw ArgumentError.value(
        maxConcurrent,
        'maxConcurrent',
        'Must be at least 1.',
      );
    }
  }

  final int maxConcurrent;
  int _active = 0;
  final Queue<Completer<void>> _queue = Queue<Completer<void>>();

  Future<T> withResource<T>(FutureOr<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future.value();
    }
    final completer = Completer<void>();
    _queue.add(completer);
    return completer.future;
  }

  void _release() {
    if (_queue.isEmpty) {
      _active--;
      return;
    }
    _queue.removeFirst().complete();
  }
}

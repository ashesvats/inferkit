import 'dart:async';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

void main() {
  test('limits concurrent work and releases after errors', () async {
    final semaphore = Semaphore(2);
    var active = 0;
    var maxActive = 0;

    Future<void> task(int index) {
      return semaphore.withResource(() async {
        active++;
        maxActive = active > maxActive ? active : maxActive;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        if (index == 2) throw StateError('boom');
      });
    }

    final results = await Future.wait([
      for (var i = 0; i < 5; i++)
        task(i).then((_) => 'ok').catchError((_) => 'err'),
    ]);

    expect(maxActive, 2);
    expect(results, contains('err'));
    expect(await semaphore.withResource(() => 'released'), 'released');
  });
}

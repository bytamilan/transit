import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

PingRecord samplePing(int i) => PingRecord(
      assignmentId: 'a1',
      ts: DateTime(2026, 1, 1, 6, 0, i),
      lat: 1.3 + i * 0.0001,
      lon: 103.8,
    );

void main() {
  group('PingQueue', () {
    test('enqueue then nextBatch returns queued pings in order', () async {
      final queue = PingQueue(storage: InMemoryPingStorage(), batchSize: 10);
      for (var i = 0; i < 3; i++) {
        await queue.enqueue(samplePing(i));
      }
      final batch = await queue.nextBatch();
      expect(batch.map((p) => p.ts.second), [0, 1, 2]);
    });

    test('caps a batch at batchSize even with more queued', () async {
      final queue = PingQueue(storage: InMemoryPingStorage(), batchSize: 10);
      for (var i = 0; i < 25; i++) {
        await queue.enqueue(samplePing(i));
      }
      final batch = await queue.nextBatch();
      expect(batch, hasLength(10));
      expect(await queue.length, 25);
    });

    test('acknowledge removes only the acknowledged batch, leaving the rest queued', () async {
      final queue = PingQueue(storage: InMemoryPingStorage(), batchSize: 10);
      for (var i = 0; i < 15; i++) {
        await queue.enqueue(samplePing(i));
      }
      final batch = await queue.nextBatch();
      await queue.acknowledge(batch);

      expect(await queue.length, 5);
      final remaining = await queue.nextBatch();
      expect(remaining.map((p) => p.ts.second), [10, 11, 12, 13, 14]);
    });

    test('a failed flush leaves the batch queued for retry', () async {
      final storage = InMemoryPingStorage();
      final queue = PingQueue(storage: storage, batchSize: 10);
      await queue.enqueue(samplePing(0));

      final batch = await queue.nextBatch();
      // Simulate an upload attempt that fails — never acknowledge.
      expect(batch, hasLength(1));
      expect(await queue.length, 1);
    });

    test('survives a simulated crash — a new queue over the same storage sees everything queued', () async {
      final storage = InMemoryPingStorage();
      final first = PingQueue(storage: storage);
      for (var i = 0; i < 4; i++) {
        await first.enqueue(samplePing(i));
      }

      // "Crash" — a fresh PingQueue instance backed by the same durable
      // storage, as would happen after an app restart.
      final second = PingQueue(storage: storage);
      expect(await second.length, 4);
      final batch = await second.nextBatch();
      expect(batch.map((p) => p.ts.second), [0, 1, 2, 3]);
    });
  });
}

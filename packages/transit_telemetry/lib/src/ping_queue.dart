import 'models.dart';

/// Persistence the [PingQueue] writes through to on every mutation, so a
/// crash, reboot or battery pull never loses a queued ping (brief §4.2
/// "persistent offline queue", and the Phase 7 gate: survive a reboot and a
/// 40-minute connectivity gap without losing a ping). The driver app
/// supplies an implementation backed by whatever local storage it likes
/// (shared_preferences, a file, sqlite) — this package stays storage-agnostic
/// and pure Dart.
abstract class PingStorage {
  Future<List<Map<String, dynamic>>> loadAll();
  Future<void> saveAll(List<Map<String, dynamic>> pings);
}

/// An in-memory [PingStorage] — useful for tests and as a fallback; the
/// driver app should use a real persistent implementation in production.
class InMemoryPingStorage implements PingStorage {
  List<Map<String, dynamic>> _pings = [];

  @override
  Future<List<Map<String, dynamic>>> loadAll() async => List.of(_pings);

  @override
  Future<void> saveAll(List<Map<String, dynamic>> pings) async {
    _pings = List.of(pings);
  }
}

/// A durable FIFO queue of pings awaiting upload, batched for the driver
/// app's flush (brief: "batch into 10-ping payloads"). Every mutating call
/// persists immediately via [storage] before returning, so state on disk is
/// never behind what the caller thinks happened.
class PingQueue {
  PingQueue({required this.storage, this.batchSize = 10});

  final PingStorage storage;
  final int batchSize;

  List<PingRecord> _pending = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await storage.loadAll();
    _pending = raw.map(PingRecord.fromJson).toList();
    _loaded = true;
  }

  /// Adds a ping to the queue and persists immediately.
  Future<void> enqueue(PingRecord ping) async {
    await _ensureLoaded();
    _pending.add(ping);
    await _persist();
  }

  /// Returns the next batch to attempt uploading (up to [batchSize]), or an
  /// empty list if nothing is queued. Does not remove them — call
  /// [acknowledge] once the upload actually succeeds, so a failed upload
  /// leaves the batch queued for retry.
  Future<List<PingRecord>> nextBatch() async {
    await _ensureLoaded();
    if (_pending.isEmpty) return const [];
    return _pending.take(batchSize).toList();
  }

  /// Removes a successfully-uploaded batch from the front of the queue and
  /// persists the result.
  Future<void> acknowledge(List<PingRecord> batch) async {
    await _ensureLoaded();
    if (batch.isEmpty) return;
    _pending = _pending.skip(batch.length).toList();
    await _persist();
  }

  Future<int> get length async {
    await _ensureLoaded();
    return _pending.length;
  }

  Future<void> _persist() => storage.saveAll(_pending.map((p) => p.toJson()).toList());
}

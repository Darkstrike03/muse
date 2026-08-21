import 'dart:async';
import 'dart:io';

/// Buffered, sequential reader over a [Socket].
///
/// One consumer performs strict byte reads (`read`) or reads up to a delimiter
/// (`readUntil`). Bytes that arrive early are buffered until asked for, so the
/// caller can hand the socket back to a real consumer (e.g. a media player)
/// after finishing control reads without losing data.
class SocketReader {
  SocketReader(this.socket) {
    _sub = socket.listen(_onData, onError: _onError, onDone: _onDone);
  }

  final Socket socket;
  final List<int> _buffer = [];
  final List<_Wait> _waiters = [];
  late final StreamSubscription<List<int>> _sub;
  Object? _failure;
  bool _closed = false;

  /// Cancels the internal listener. Pending reads resolve with [SocketException].
  void close() {
    _sub.cancel();
    _fail(const SocketException('socket reader closed'));
  }

  void _onData(List<int> data) {
    _buffer.addAll(data);
    _pump();
  }

  void _onError(Object error) => _fail(error);

  void _onDone() {
    _closed = true;
    _fail(const SocketException('connection closed'));
  }

  void _fail(Object error) {
    _failure ??= error;
    for (final wait in _waiters) {
      if (!wait.completer.isCompleted) wait.completer.completeError(error);
    }
    _waiters.clear();
  }

  void _pump() {
    for (final wait in _waiters) {
      if (!wait.completer.isCompleted && wait.ready()) {
        wait.completer.complete();
      }
    }
  }

  /// Reads exactly [count] bytes.
  Future<List<int>> read(int count) async {
    if (count == 0) return const [];
    if (_failure != null) throw _failure!;
    if (_buffer.length >= count) return _take(count);
    await _waitFor(() => _buffer.length >= count);
    return _take(count);
  }

  /// Reads bytes up to and including [delimiter].
  Future<List<int>> readUntil(List<int> delimiter) async {
    if (_failure != null) throw _failure!;
    final index = _indexOf(delimiter);
    if (index >= 0) return _takeThrough(index + delimiter.length);
    await _waitFor(() => _indexOf(delimiter) >= 0);
    final found = _indexOf(delimiter);
    return _takeThrough(found + delimiter.length);
  }

  /// Reads whatever is buffered right now, waiting until at least one byte is
  /// available or the connection closes. Returns `const []` at end of stream.
  /// Used to forward a raw stream once control reads are done.
  Future<List<int>> readAvailable() async {
    if (_buffer.isNotEmpty) return _take(_buffer.length);
    if (_closed) return const [];
    await _waitFor(() => _buffer.isNotEmpty || _closed);
    if (_buffer.isNotEmpty) return _take(_buffer.length);
    return const [];
  }

  /// Whether the underlying connection has closed.
  bool get isClosed => _closed;

  Future<void> _waitFor(bool Function() ready) async {
    final wait = _Wait(ready);
    _waiters.add(wait);
    try {
      await wait.completer.future.timeout(const Duration(seconds: 60));
    } finally {
      _waiters.remove(wait);
    }
  }

  List<int> _take(int count) {
    final out = _buffer.sublist(0, count);
    _buffer.removeRange(0, count);
    return out;
  }

  List<int> _takeThrough(int end) {
    final out = _buffer.sublist(0, end);
    _buffer.removeRange(0, end);
    return out;
  }

  int _indexOf(List<int> needle) {
    if (needle.isEmpty || _buffer.length < needle.length) return -1;
    for (var i = 0; i <= _buffer.length - needle.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (_buffer[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}

class _Wait {
  _Wait(this.ready);

  final bool Function() ready;
  final Completer<void> completer = Completer<void>();
}
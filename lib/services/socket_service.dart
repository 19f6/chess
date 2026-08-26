import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin wrapper around a single socket.io connection to the chess server.
///
/// Two interaction styles are exposed to match the server's contract:
///  - request/response events (`game:create`, `game:move`, ...) use
///    [emitAck], which resolves a Future from the server's ack callback.
///  - server-pushed events (`game:state`, `game:your_turn`, ...) use [on]
///    to register a persistent listener.
class SocketService {
  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Creates the underlying (not-yet-connected) socket. Must be called once
  /// at app startup, before any provider registers listeners via [on] --
  /// listeners attach to this same long-lived socket object regardless of
  /// whether [open] has been called yet.
  void init(String url) {
    if (_socket != null) return;
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  /// Opens the connection created by [init]. Safe to call again after
  /// [disconnect] (e.g. switching players) since `socket.connect()`
  /// reconnects the same client.
  Future<void> open() {
    final socket = _socket;
    if (socket == null) {
      throw StateError('SocketService.init() must be called before open()');
    }
    if (socket.connected) return Future.value();
    final completer = Completer<void>();
    socket.onConnect((_) {
      if (!completer.isCompleted) completer.complete();
    });
    socket.onConnectError((err) {
      if (!completer.isCompleted) completer.completeError(err ?? 'Connection error');
    });
    socket.connect();
    return completer.future;
  }

  void disconnect() {
    _socket?.disconnect();
  }

  Future<Map<String, dynamic>> emitAck(String event, [Map<String, dynamic>? data]) {
    final completer = Completer<Map<String, dynamic>>();
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.value({'ok': false, 'error': 'Not connected to server'});
    }
    socket.emitWithAck(
      event,
      data ?? <String, dynamic>{},
      ack: (dynamic response) {
        if (response is Map) {
          completer.complete(Map<String, dynamic>.from(response));
        } else {
          completer.complete({'ok': false, 'error': 'Malformed server response'});
        }
      },
    );
    // Guard against a server bug/crash never firing the ack.
    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.complete({'ok': false, 'error': 'Server did not respond in time'});
      }
    });
    return completer.future;
  }

  void emit(String event, [Map<String, dynamic>? data]) {
    _socket?.emit(event, data ?? <String, dynamic>{});
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  /// Removes a specific handler previously passed to [on]. Pass no handler
  /// to remove *all* listeners for [event] -- callers with more than one
  /// active listener on the same event (e.g. multiple providers) must pass
  /// the exact handler reference to avoid clobbering each other.
  void off(String event, [void Function(dynamic data)? handler]) {
    _socket?.off(event, handler);
  }
}

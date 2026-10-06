import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../app_controller.dart';
import '../../features/auth/auth_controller.dart';
import '../network/kredi_api.dart';

/// Sincronización de baja latencia para Kredi+ en hosting compartido.
///
/// Mantiene una sola petición long-poll abierta. El servidor responde apenas
/// detecta un cambio relevante y la app refresca únicamente el contexto que
/// corresponda. Si la red se cae, reintenta con backoff sin bloquear la UI.
class RealtimeCoordinator extends ChangeNotifier {
  RealtimeCoordinator(this.api, this.auth, this.app);

  final KrediApi api;
  final AuthController auth;
  final AppController app;

  bool _running = false;
  bool _foreground = true;
  String _cursor = '';
  int _generation = 0;
  Set<String> _lastChannels = const <String>{};
  final Map<String, int> _channelGenerations = <String, int>{};
  int _retryAttempt = 0;
  int _runId = 0;

  bool get running => _running;
  bool get foreground => _foreground;
  int get generation => _generation;
  Set<String> get lastChannels => _lastChannels;

  int generationFor(Iterable<String> channels) {
    var value = 0;
    for (final channel in channels) {
      final candidate = _channelGenerations[channel] ?? 0;
      if (candidate > value) value = candidate;
    }
    return value;
  }

  void start() {
    if (_running || !_foreground || !auth.isAuthenticated) return;
    _running = true;
    _retryAttempt = 0;
    final runId = ++_runId;
    unawaited(_loop(runId));
  }


  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (!value) {
      stop();
    } else if (auth.isAuthenticated) {
      start();
    }
  }

  void stop({bool clearCursor = false}) {
    _running = false;
    _runId++;
    if (clearCursor) {
      _cursor = '';
      _channelGenerations.clear();
      _lastChannels = const <String>{};
    }
  }

  Future<void> _loop(int runId) async {
    while (_running && runId == _runId && _foreground && auth.isAuthenticated) {
      try {
        final result = await api.waitForSync(
          cursor: _cursor,
          waitSeconds: 18,
        );
        if (!_running || runId != _runId || !_foreground || !auth.isAuthenticated) return;

        final nextCursor = result['cursor']?.toString() ?? '';
        if (nextCursor.isNotEmpty) _cursor = nextCursor;
        final rawChanged = result['changed'];
        final changed = rawChanged is List
            ? rawChanged.map((e) => e.toString()).toSet()
            : <String>{};

        _retryAttempt = 0;
        if (changed.isEmpty) continue;

        final refreshes = <Future<void>>[];
        if (changed.contains('catalog')) {
          refreshes.add(app.refreshCatalog(silent: true));
        }
        if (changed.any(
          (channel) => const {'profile', 'credit'}.contains(channel),
        )) {
          refreshes.add(auth.refreshProfile());
        }
        // Catálogo y perfil/crédito se actualizan en paralelo. El resto de
        // pantallas se recrea una sola vez después de completar el lote.
        if (refreshes.isNotEmpty) await Future.wait(refreshes);
        if (!_running || runId != _runId || !auth.isAuthenticated) return;

        _lastChannels = changed;
        _generation++;
        for (final channel in changed) {
          _channelGenerations[channel] = _generation;
        }
        notifyListeners();
      } catch (_) {
        if (!_running || runId != _runId || !_foreground || !auth.isAuthenticated) return;
        _retryAttempt = (_retryAttempt + 1).clamp(1, 6).toInt();
        final seconds = switch (_retryAttempt) {
          1 => 1,
          2 => 2,
          3 => 3,
          4 => 5,
          5 => 8,
          _ => 12,
        };
        await Future<void>.delayed(Duration(seconds: seconds));
      }
    }
  }
}

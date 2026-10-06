import 'package:flutter/widgets.dart';
import 'app_controller.dart';
import 'core/network/kredi_api.dart';
import 'core/realtime/realtime_coordinator.dart';
import 'features/auth/auth_controller.dart';
import 'features/security/app_lock_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.app,
    required this.realtime,
    required this.lock,
    required super.child,
  });

  final KrediApi api;
  final AuthController auth;
  final AppController app;
  final RealtimeCoordinator realtime;
  final AppLockController lock;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      auth != oldWidget.auth ||
      app != oldWidget.app ||
      realtime != oldWidget.realtime ||
      lock != oldWidget.lock;
}

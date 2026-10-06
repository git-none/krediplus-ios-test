import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_controller.dart';
import 'app_scope.dart';
import 'core/network/api_client.dart';
import 'core/network/kredi_api.dart';
import 'core/storage/session_store.dart';
import 'core/realtime/realtime_coordinator.dart';
import 'core/security/biometric_service.dart';
import 'core/theme/kredi_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/pin_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/kredi_splash_screen.dart';
import 'features/security/app_lock_controller.dart';
import 'features/security/app_lock_screen.dart';
import 'features/stores/bodega_evidence_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  final store = SessionStore();
  final client = ApiClient(store);
  final api = KrediApi(client);
  final auth = AuthController(api, store);
  final app = AppController(api);
  final realtime = RealtimeCoordinator(api, auth, app);
  final lock = AppLockController(store, BiometricService());

  runApp(
    KrediPlus(
      api: api,
      auth: auth,
      app: app,
      realtime: realtime,
      lock: lock,
    ),
  );
}

class KrediPlus extends StatefulWidget {
  const KrediPlus({
    super.key,
    required this.api,
    required this.auth,
    required this.app,
    required this.realtime,
    required this.lock,
  });

  final KrediApi api;
  final AuthController auth;
  final AppController app;
  final RealtimeCoordinator realtime;
  final AppLockController lock;

  @override
  State<KrediPlus> createState() => _KrediPlusState();
}

class _KrediPlusState extends State<KrediPlus> with WidgetsBindingObserver {
  bool _bootDone = false;
  bool _onboardingDone = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_authChanged);
    widget.realtime.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.lock.handleLifecycle(state);
    // Modo estable: no se reinicia ninguna sincronización global al cambiar
    // entre primer y segundo plano. Las pantallas se actualizan a petición.
    if (state == AppLifecycleState.detached) {
      widget.realtime.stop();
    }
  }

  void _authChanged() {
    // Evita que una sesión autenticada reconstruya pantallas por cambios
    // remotos. El usuario conserva los resultados hasta que decida refrescar.
    if (!widget.auth.isAuthenticated) {
      widget.realtime.stop(clearCursor: true);
      widget.lock.clearRuntime();
      return;
    }
    widget.lock.bindUser(widget.auth.user);
  }

  Future<void> _boot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingDone = prefs.getBool('kredi_onboarding_v1_done') ?? false;
      await Future.wait([
        widget.auth.initialize(),
        Future<void>.delayed(const Duration(milliseconds: 1100)),
      ]);
      await widget.lock.bindUser(
        widget.auth.user,
        lockImmediately: widget.auth.isAuthenticated,
      );
    } finally {
      if (mounted) setState(() => _bootDone = true);
    }
  }

  @override
  Widget build(BuildContext context) => AppScope(
    api: widget.api,
    auth: widget.auth,
    app: widget.app,
    realtime: widget.realtime,
    lock: widget.lock,
    child: MaterialApp(
      title: 'Kredi+',
      debugShowCheckedModeBanner: false,
      theme: krediTheme(),
      locale: const Locale('es', 'VE'),
      supportedLocales: const [Locale('es', 'VE'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: .9,
              maxScaleFactor: 1.0,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) {
        final raw = settings.name ?? '';
        final uri = Uri.tryParse(raw);
        final isBodega = uri != null &&
            ((uri.host == 'bodegas' && uri.path == '/continuar') ||
                uri.path == '/bodegas/continuar');
        if (isBodega) {
          final code = uri.queryParameters['codigo'] ?? '';
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => BodegaEvidenceScreen(initialCode: code),
          );
        }
        return null;
      },
      home: !_bootDone
          ? const KrediSplashScreen()
          : AnimatedBuilder(
              animation: widget.auth,
              builder: (context, _) {
                if (!widget.auth.initialized) return const KrediSplashScreen();
                if (widget.auth.isAuthenticated) {
                  return AnimatedBuilder(
                    animation: widget.lock,
                    child: const AppShell(),
                    builder: (context, shell) => widget.lock.locked
                        ? const AppLockScreen()
                        : shell!,
                  );
                }
                if (widget.auth.needsPin) return const PinScreen();
                if (!_onboardingDone) {
                  return OnboardingScreen(
                    onDone: () => setState(() => _onboardingDone = true),
                  );
                }
                return const LoginScreen();
              },
            ),
    ),
  );
}

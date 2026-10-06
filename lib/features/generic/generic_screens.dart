import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../stores/stores_screen.dart';
import '../stores/bodega_evidence_screen.dart';
import '../profile/privacy_screen.dart';
import '../profile/account_deletion_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const KrediScreenTitle(
          'Configuración',
          subtitle: 'Seguridad y preferencias de tu cuenta.',
        ),
        const SizedBox(height: 18),
        KrediOutlineCard(
          child: Column(
            children: [
              KrediMenuRow(
                icon: KrediIcons.sync,
                title: 'Actualizar datos',
                subtitle: 'Actualiza los datos de Kredi+.',
                onTap: () async {
                  await scope.app.refreshCatalog();
                  if (context.mounted) {
                    showKrediMessage(context, 'Datos actualizados.');
                  }
                },
              ),
              const Divider(height: 1),
              const KrediMenuRow(
                icon: KrediIcons.shield,
                title: 'Seguridad',
                subtitle:
                    'PIN, sesiones y protección de la cuenta.',
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.privacy,
                title: 'Privacidad',
                subtitle: 'Consulta los controles y la política de privacidad.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.delete,
                iconColor: KrediColors.danger,
                title: 'Eliminar cuenta',
                subtitle: 'Inicia una solicitud de eliminación verificada por correo.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountDeletionScreen()),
                ),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.info,
                title: 'Versión',
                subtitle:
                    'Kredi+ Mobile ${AppConfig.versionName}+${AppConfig.versionCode} · com.krediplus.nativeapp',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => scope.auth.logout(),
          icon: const Icon(KrediIcons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.controller, this.scanCode});

  final MobileScannerController? controller;
  final Future<Map<String, dynamic>> Function(String code)? scanCode;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _camera;
  bool _processing = false;
  bool _pausedAfterError = false;
  bool _startingCamera = false;
  String? _error;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _camera =
        widget.controller ??
        MobileScannerController(
          autoStart: false,
          formats: const [BarcodeFormat.qrCode],
          detectionSpeed: DetectionSpeed.normal,
          detectionTimeoutMs: 750,
        );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  bool get _canScan =>
      mounted &&
      !_processing &&
      !_pausedAfterError &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_startCamera());
    } else if (!_camera.value.isStarting) {
      // The permission dialog itself briefly makes the app inactive.
      unawaited(_stopCamera());
    }
  }

  Future<void> _startCamera() async {
    if (!_canScan || _startingCamera || _camera.value.isRunning) return;
    _startingCamera = true;
    try {
      await _camera.start();
      if (!_canScan) await _stopCamera();
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError =
              'No pudimos abrir la cámara. Inténtalo nuevamente.',
        );
      }
    } finally {
      _startingCamera = false;
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _camera.stop();
    } catch (_) {
      // Disposal and lifecycle changes can both release the same camera.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _cameraError = null;
      _pausedAfterError = false;
    });
    await _startCamera();
  }

  Future<void> _detected(String rawCode) async {
    final code = rawCode.trim();
    if (!_canScan || code.isEmpty) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    await _stopCamera();
    if (!mounted) return;
    try {
      final registrationMatch = RegExp(
        r'KPBREG-[A-Z0-9]+',
        caseSensitive: false,
      ).firstMatch(code);
      if (registrationMatch != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => BodegaEvidenceScreen(
              initialCode: registrationMatch.group(0)!.toUpperCase(),
            ),
          ),
        );
        return;
      }

      // Los QR KPB identifican una bodega y abren su catálogo; no crean una
      // compra hasta que el usuario seleccione qué producto o combo desea.
      if (RegExp(r'KPB-[A-Z0-9]+', caseSensitive: false).hasMatch(code)) {
        final catalog = await AppScope.of(context).api.scanCommunityStore(code);
        if (!mounted) return;
        final store = catalog['store'] is Map
            ? Map<String, dynamic>.from(catalog['store'] as Map)
            : <String, dynamic>{};
        final storeId = jInt(store, ['id']);
        if (storeId <= 0) throw ApiException('No pudimos identificar esta bodega.');
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CommunityStoreCatalogScreen(
              storeId: storeId,
              initialStore: store,
              initialCatalog: catalog,
            ),
          ),
        );
        return;
      }

      final purchase =
          await (widget.scanCode ?? AppScope.of(context).api.startQrPurchase)(
            code,
          );
      if (!mounted) return;
      // Scanning only opens the review. The user confirms on the next screen.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _QrPurchaseSessionScreen(initial: purchase),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _pausedAfterError = true;
          _error = e is ApiException
              ? e.message
              : 'No pudimos consultar este código. Revisa tu conexión e inténtalo nuevamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        await _startCamera();
      }
    }
  }

  String _permissionMessage(
    MobileScannerException error,
  ) => switch (error.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Activa el permiso de Cámara para Kredi+ y vuelve a intentar.',
    MobileScannerErrorCode.unsupported =>
      'Este dispositivo no tiene una cámara compatible con el lector QR.',
    _ =>
      'No pudimos abrir la cámara. Inténtalo nuevamente.',
  };

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _camera,
          builder: (context, cameraState, _) {
            final cameraError = cameraState.error;
            final errorMessage =
                _error ??
                _cameraError ??
                (cameraError == null ? null : _permissionMessage(cameraError));
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _camera,
                  useAppLifecycleState: false,
                  tapToFocus: true,
                  errorBuilder: (_, _) => const ColoredBox(
                    color: Color(0xFF111214),
                    child: Center(
                      child: Icon(
                        KrediIcons.noPhoto,
                        color: Colors.white70,
                        size: 54,
                      ),
                    ),
                  ),
                  placeholderBuilder: (_) => const ColoredBox(
                    color: Color(0xFF111214),
                    child: Center(
                      child: CircularProgressIndicator(color: KrediColors.orange),
                    ),
                  ),
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final code = barcode.rawValue;
                      if (code != null && code.trim().isNotEmpty) {
                        unawaited(_detected(code));
                        break;
                      }
                    }
                  },
                  onDetectError: (_, _) {
                    if (mounted && !_processing) {
                      setState(() {
                        _error =
                            'No pudimos leer el QR. Acércalo y vuelve a intentarlo.';
                        _pausedAfterError = true;
                      });
                      unawaited(_stopCamera());
                    }
                  },
                ),
                const _ScannerShade(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _ScannerCircleButton(
                              tooltip: 'Volver',
                              icon: KrediIcons.back,
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const Spacer(flex: 2),
                        const Text(
                          'Escanea el QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.35,
                            shadows: [
                              Shadow(color: Color(0x66000000), blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Apunta al QR del comercio',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Color(0x66000000), blurRadius: 7),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        const _ScannerFrame(),
                        const Spacer(flex: 3),
                        AnimatedSwitcher(
                          duration: KrediMotion.standard,
                          child: _processing
                              ? const _ScannerStatus(
                                  key: ValueKey('processing'),
                                  icon: KrediIcons.qr,
                                  text: 'Leyendo QR…',
                                )
                              : errorMessage != null
                                  ? _ScannerError(
                                      key: const ValueKey('error'),
                                      message: errorMessage,
                                      onRetry: _retry,
                                    )
                                  : const _ScannerStatus(
                                      key: ValueKey('ready'),
                                      icon: KrediIcons.qr,
                                      text: 'La lectura es automática',
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_processing)
                  const IgnorePointer(
                    child: ColoredBox(color: Color(0x26000000)),
                  ),
              ],
            );
          },
        ),
      ),
    );
}

class _ScannerShade extends StatelessWidget {
  const _ScannerShade();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .56),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: .58),
              ],
              stops: const [0, .24, .70, 1],
            ),
          ),
        ),
      );
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    final side = (MediaQuery.sizeOf(context).width - 70).clamp(230.0, 320.0);
    return SizedBox(
      width: side,
      height: side,
      child: CustomPaint(painter: _ScannerFramePainter()),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final accent = Paint()
      ..color = KrediColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const radius = 24.0;
    const arm = 48.0;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    Path corner(double x, double y, bool right, bool bottom) {
      final p = Path();
      final sx = right ? -1.0 : 1.0;
      final sy = bottom ? -1.0 : 1.0;
      p.moveTo(x, y + sy * arm);
      p.lineTo(x, y + sy * radius);
      p.quadraticBezierTo(x, y, x + sx * radius, y);
      p.lineTo(x + sx * arm, y);
      return p;
    }

    final paths = [
      corner(rect.left, rect.top, false, false),
      corner(rect.right, rect.top, true, false),
      corner(rect.left, rect.bottom, false, true),
      corner(rect.right, rect.bottom, true, true),
    ];
    for (final p in paths) canvas.drawPath(p, shadow);
    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(paths[i], i == 1 ? accent : paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerCircleButton extends StatelessWidget {
  const _ScannerCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: KrediPressable(
          onTap: onTap,
          pressedScale: .92,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .48),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      );
}

class _ScannerStatus extends StatelessWidget {
  const _ScannerStatus({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .48),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: KrediColors.orange),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(KrediIcons.error, color: Colors.white, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.3),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: KrediColors.orange),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
}

class _QrPurchaseSessionScreen extends StatefulWidget {
  const _QrPurchaseSessionScreen({required this.initial});
  final Map<String, dynamic> initial;
  @override
  State<_QrPurchaseSessionScreen> createState() =>
      _QrPurchaseSessionScreenState();
}

class _QrPurchaseSessionScreenState extends State<_QrPurchaseSessionScreen> {
  late Map<String, dynamic> data;
  bool busy = false, stopped = false;
  @override
  void initState() {
    super.initState();
    data = widget.initial;
    _poll();
  }

  @override
  void dispose() {
    stopped = true;
    super.dispose();
  }

  Future<void> _poll() async {
    while (!stopped && mounted) {
      final st = jString(data, ['status']).toUpperCase();
      if ({'COMPLETED', 'EXPIRED', 'CANCELLED'}.contains(st)) return;
      await Future<void>.delayed(const Duration(seconds: 10));
      if (stopped || !mounted) return;
      await _refreshSession();
    }
  }

  Future<void> _refreshSession({bool manual = false}) async {
    try {
      final id = jInt(data, ['id']);
      if (id <= 0) return;
      final next = await AppScope.of(context).api.qrPurchaseSession(
        id,
        commerceFlow: data['commerceFlow'] != false,
      );
      if (!mounted) return;
      if (next.toString() != data.toString()) {
        setState(() => data = next);
      }
      if (manual) showKrediMessage(context, 'Estado actualizado.');
    } catch (e) {
      if (manual && mounted) showKrediMessage(context, e.toString());
    }
  }

  Future<void> _confirm() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final next = await AppScope.of(context).api.confirmQrPurchase(
        jInt(data, ['id']),
        commerceFlow: data['commerceFlow'] != false,
      );
      if (mounted) setState(() => data = next);
    } catch (e) {
      if (mounted) showKrediMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _money(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null) return 'Por definir';
    return 'US\$ ${n.toStringAsFixed(2)}';
  }

  String get typeLabel => switch (jString(data, ['offerType']).toUpperCase()) {
    'JOURNEY' => 'Jornada',
    'COMBO' => 'Combo',
    'OFFER' => 'Oferta',
    _ => 'Compra por QR',
  };
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    final status = jString(data, ['status']).toUpperCase();
    final completed = status == 'COMPLETED';
    final items = jList(data, ['items']);
    final cover = jString(data, ['coverUrl']);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(typeLabel),
        leading: IconButton(
          icon: const Icon(KrediIcons.close),
          tooltip: 'Volver al lector QR',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: cover,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (cover.isNotEmpty) const SizedBox(height: 16),
            Text(
              jString(data, ['offerName'], 'Compra en el comercio'),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              jString(data, ['businessName'], 'Negocio Kredi+'),
              style: const TextStyle(
                color: KrediColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (status == 'AWAITING_MERCHANT') ...[
              const KrediOutlineCard(
                color: KrediColors.softOrange,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(KrediIcons.storefront, size: 30),
                    SizedBox(height: 12),
                    Text(
                      'QR leído correctamente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Espera el monto del comercio para continuar.',
                      style: TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (data['totalUsd'] != null) ...[
              Text(
                _money(data['totalUsd']),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const Text(
                'Precio de la oferta',
                style: TextStyle(
                  color: KrediColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 22),
              const KrediSectionRow(title: 'Incluye'),
              const SizedBox(height: 8),
              Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    if (items[i] is Map)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == items.length - 1 ? 0 : 10,
                        ),
                        child: _QrSessionItemCard(
                          item: Map<String, dynamic>.from(items[i] as Map),
                          app: app,
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (data['initialUsd'] != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KrediColors.background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _planRow(
                      'Hoy · inicial',
                      _money(0),
                      strong: true,
                    ),
                    const Divider(height: 25),
                    _planRow('Usas de tu línea', _money(data['totalUsd'] ?? data['financedUsd'])),
                    if (jInt(data, ['installmentCount']).clamp(0, KrediCreditPolicy.maximumInstallments) > 0) ...[
                      const Divider(height: 25),
                      _planRow(
                        '${jInt(data, ['installmentCount']).clamp(1, KrediCreditPolicy.maximumInstallments)} cuotas',
                        _money(data['installmentUsd']),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (data['level'] != null)
              Row(
                children: [
                  Expanded(
                    child: _MiniFact(
                      'Tu nivel',
                      '${jInt(data, ['level'])} · ${jString(data, ['levelName'])}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniFact(
                      'Disponible',
                      _money(data['availableLineUsd']),
                    ),
                  ),
                ],
              ),
            if (data['stockRemaining'] != null) ...[
              const SizedBox(height: 10),
              Text(
                'Disponibles: ${jInt(data, ['stockRemaining'])}${data['onePurchasePerUser'] == true ? ' · 1 por usuario' : ''}',
                style: const TextStyle(
                  color: KrediColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (status == 'AWAITING_CONFIRMATION' ||
                status == 'AWAITING_CUSTOMER')
              KrediActionButton(
                icon: KrediIcons.checkout,
                label: 'Comprar con Kredi+',
                onPressed: _confirm,
                busy: busy,
                expanded: true,
              ),
            if (status == 'AWAITING_INITIAL')
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KrediColors.softOrange,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Icon(KrediIcons.storefront, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Compra registrada · 0% inicial',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tus cuotas se activarán al completar la confirmación de la compra.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KrediColors.secondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            if (completed)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KrediColors.softGreen,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    Icon(
                      KrediIcons.confirm,
                      color: KrediColors.green,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Compra aprobada',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tu compra quedó registrada y tus cuotas están activas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KrediColors.secondary),
                    ),
                  ],
                ),
              ),
            if (status == 'EXPIRED')
              const KrediEmptyState(
                icon: KrediIcons.expired,
                title: 'La reserva venció',
                message:
                    'Escanea nuevamente el QR para volver a validar disponibilidad.',
              ),
            if (status == 'CANCELLED')
              const KrediEmptyState(
                icon: KrediIcons.cancel,
                title: 'Compra cancelada',
                message:
                    'Esta sesión terminó. Puedes volver al lector para iniciar otra compra.',
              ),
            if (!completed && status != 'EXPIRED' && status != 'CANCELLED') ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _refreshSession(manual: true),
                icon: const Icon(KrediIcons.refresh),
                label: const Text('Actualizar estado'),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              jString(data, ['message']),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KrediColors.secondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planRow(String a, String b, {bool strong = false}) => Row(
    children: [
      Expanded(
        child: Text(
          a,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        b,
        style: TextStyle(
          fontSize: strong ? 18 : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _QrSessionItemCard extends StatelessWidget {
  const _QrSessionItemCard({required this.item, required this.app});

  final Map<String, dynamic> item;
  final dynamic app;

  Map<String, dynamic>? _catalogProduct() {
    final id = jInt(item, ['productId', 'id']);
    if (id > 0) {
      final row = app.productById(id);
      if (row != null) return row;
    }
    final name = jString(item, ['name', 'productName']).trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final product in app.products as List<Map<String, dynamic>>) {
      if (jString(product, ['name']).trim().toLowerCase() == name) {
        return product;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final product = _catalogProduct();
    final quantity = jInt(item, ['quantity'], 1);
    var unitPrice = jDouble(item, ['unitPriceUsd', 'priceUsd']);
    if (unitPrice <= 0 && product != null) {
      unitPrice = app.productPriceUsd(product) as double;
    }
    final directImage = jString(item, [
      'imageUrl',
      'imagePath',
      'productImageUrl',
      'productImagePath',
      'image',
    ]);
    final image = AppConfig.publicUrl(
      directImage.isNotEmpty
          ? directImage
          : product == null
              ? ''
              : jString(product, ['imageUrl', 'imagePath', 'image']),
    );
    final name = jString(
      item,
      ['name', 'productName'],
      product == null ? 'Producto' : jString(product, ['name'], 'Producto'),
    );

    return KrediOutlineCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: image.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF7F7F8),
                      child: Center(
                        child: Icon(
                          KrediIcons.image,
                          size: 26,
                          color: KrediColors.secondary,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF7F7F8),
                        child: Center(
                          child: Icon(
                            KrediIcons.image,
                            size: 26,
                            color: KrediColors.secondary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Cantidad: $quantity',
                  style: const TextStyle(
                    fontSize: 12,
                    color: KrediColors.secondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unitPrice > 0
                      ? 'US\$ ${unitPrice.toStringAsFixed(2)} c/u'
                      : 'Precio no disponible',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (unitPrice > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Subtotal: US\$ ${(unitPrice * quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KrediColors.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: KrediColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: KrediColors.secondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class UserSummaryScreen extends StatelessWidget {
  const UserSummaryScreen({super.key});

  static final List<Map<String, dynamic>> _fallbackRules =
      KrediCreditPolicy.levelRules;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        api.purchases().timeout(const Duration(seconds: 15), onTimeout: () => <Map<String, dynamic>>[]),
        api.credit().timeout(const Duration(seconds: 15)),
      ]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return KrediEmptyState(
            icon: KrediIcons.credit,
            title: 'No pudimos cargar tu nivel',
            actionLabel: 'Reintentar',
            onAction: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const UserSummaryScreen()),
            ),
          );
        }

        final purchases = snap.data?[0] is List ? snap.data![0] as List : const [];
        final credit = snap.data?[1] is Map
            ? Map<String, dynamic>.from(snap.data![1] as Map)
            : const <String, dynamic>{};
        final currentLevel = jInt(credit, ['level'], 1).clamp(1, 6).toInt();
        final completed = jInt(credit, ['completedPayments']);
        final rawRules = jList(credit, ['levelRules'])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final rules = rawRules.isEmpty ? _fallbackRules : rawRules;
        final altura = credit['alturaLine'] is Map
            ? Map<String, dynamic>.from(credit['alturaLine'] as Map)
            : <String, dynamic>{};
        final alturaEligible = jBool(altura, ['eligible']);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          children: [
            const Text(
              'Tu recorrido Kredi+',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            const Text(
              'Desliza para conocer cada nivel.',
              style: TextStyle(
                fontSize: 12.5,
                color: KrediColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            _KrediLevelCarousel(
              rules: rules.cast<Map<String, dynamic>>(),
              currentLevel: currentLevel,
              completedPayments: completed,
              completedPurchases: purchases.length,
            ),
            if (alturaEligible) ...[
              const SizedBox(height: 16),
              const KrediOutlineCard(
                color: KrediColors.softGreen,
                child: Row(
                  children: [
                    Icon(KrediIcons.success, size: 22, color: KrediColors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kredi Altura está activa en tu cuenta.',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

}



class _KrediLevelCarousel extends StatefulWidget {
  const _KrediLevelCarousel({
    required this.rules,
    required this.currentLevel,
    required this.completedPayments,
    required this.completedPurchases,
  });

  final List<Map<String, dynamic>> rules;
  final int currentLevel;
  final int completedPayments;
  final int completedPurchases;

  @override
  State<_KrediLevelCarousel> createState() => _KrediLevelCarouselState();
}

class _KrediLevelCarouselState extends State<_KrediLevelCarousel> {
  late final PageController controller;
  late int selected;

  @override
  void initState() {
    super.initState();
    selected = (widget.currentLevel - 1).clamp(0, widget.rules.length - 1);
    controller = PageController(
      initialPage: selected,
      viewportFraction: .92,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  IconData _iconForLevel(int level) {
    switch (level) {
      case 1:
        return KrediIcons.location;
      case 2:
        return KrediIcons.guide;
      case 3:
        return KrediIcons.visibility;
      case 4:
        return KrediIcons.award;
      case 5:
        return KrediIcons.premium;
      default:
        return KrediIcons.sparkle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 330,
          child: PageView.builder(
            controller: controller,
            itemCount: widget.rules.length,
            onPageChanged: (value) => setState(() => selected = value),
            itemBuilder: (context, index) {
              final rule = widget.rules[index];
              final level = jInt(rule, ['level'], index + 1);
              final name = KrediCreditPolicy.ruleFor(level).name;
              final current = level == widget.currentLevel;
              final reached = level <= widget.currentLevel;
              final sendero = jDouble(
                rule,
                ['senderoLimitUsd', 'baseAmountUsd'],
              );
              final altura = jDouble(rule, ['alturaLimitUsd']);
              final installments = KrediCreditPolicy.ruleFor(level).maxInstallments;
              final required = jInt(rule, ['completedPaymentsRequired']);
              final nextIndex = index + 1;
              final nextRequired = nextIndex < widget.rules.length
                  ? jInt(
                      widget.rules[nextIndex],
                      ['completedPaymentsRequired'],
                    )
                  : required;
              final range = nextRequired > required
                  ? nextRequired - required
                  : 1;
              final progress = current && level < 6
                  ? ((widget.completedPayments - required) / range)
                      .clamp(0.0, 1.0)
                      .toDouble()
                  : reached
                      ? 1.0
                      : 0.0;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.rules.length - 1 ? 0 : 10,
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: current
                          ? KrediColors.orange
                          : KrediColors.border,
                      width: current ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 135,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: _KrediMountainPainter(),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              top: 18,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: current
                                      ? KrediColors.orange
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: KrediColors.border,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  _iconForLevel(level),
                                  color: current
                                      ? Colors.white
                                      : KrediColors.orangeDeep,
                                  size: 25,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 18,
                              top: 20,
                              child: Text(
                                '$level',
                                style: const TextStyle(
                                  fontSize: 44,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: KrediColors.black,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              bottom: 16,
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            18,
                            16,
                            18,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _LevelMetric(
                                    label: 'Sendero',
                                    value: 'US\$ ${sendero.toStringAsFixed(0)}',
                                  ),
                                  if (altura > 0)
                                    _LevelMetric(
                                      label: 'Altura',
                                      value: 'US\$ ${altura.toStringAsFixed(0)}',
                                    ),
                                  _LevelMetric(
                                    label: 'Cuotas',
                                    value: '$installments',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(
                                    reached
                                        ? KrediIcons.success
                                        : KrediIcons.lock,
                                    size: 18,
                                    color: reached
                                        ? KrediColors.green
                                        : KrediColors.secondary,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    current
                                        ? 'Nivel actual'
                                        : reached
                                            ? 'Nivel alcanzado'
                                            : 'Por alcanzar',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (current) ...[
                                const SizedBox(height: 13),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 7,
                                    backgroundColor:
                                        const Color(0xFFF0F0F1),
                                    color: KrediColors.orange,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  level >= 6
                                      ? 'Salto Ángel alcanzado'
                                      : '${widget.completedPayments} pagos completados · ${widget.completedPurchases} compras',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: KrediColors.secondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.rules.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected == i ? 20 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selected == i
                      ? KrediColors.orangeDeep
                      : KrediColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LevelMetric extends StatelessWidget {
  const _LevelMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: KrediColors.secondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _KrediMountainPainter extends CustomPainter {
  const _KrediMountainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = const Color(0xFFFFE4C2);
    final middle = Paint()..color = const Color(0xFFFFBF87);
    final strong = Paint()..color = const Color(0xFFFF8B4A);

    final p1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * .34, size.height * .28)
      ..lineTo(size.width * .62, size.height)
      ..close();
    canvas.drawPath(p1, soft);

    final p2 = Path()
      ..moveTo(size.width * .32, size.height)
      ..lineTo(size.width * .64, size.height * .12)
      ..lineTo(size.width * .90, size.height)
      ..close();
    canvas.drawPath(p2, middle);

    final p3 = Path()
      ..moveTo(size.width * .62, size.height)
      ..lineTo(size.width * .86, size.height * .36)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p3, strong);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserWalletScreen extends StatelessWidget {
  const UserWalletScreen({
    super.key,
    required this.onOpenCredit,
    required this.onOpenMovements,
  });

  final VoidCallback onOpenCredit;
  final VoidCallback onOpenMovements;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        api.credit().timeout(const Duration(seconds: 15)),
        api.creditTransactions().timeout(const Duration(seconds: 15), onTimeout: () => <Map<String, dynamic>>[]),
      ]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const KrediEmptyState(
            icon: KrediIcons.wallet,
            title: 'No pudimos cargar tus líneas Kredi+',
            message: 'Revisa tu conexión e inténtalo nuevamente.',
          );
        }
        final credit = snap.data?[0] is Map
            ? Map<String, dynamic>.from(snap.data![0] as Map)
            : const <String, dynamic>{};
        final tx = snap.data?[1] is List ? snap.data![1] as List : const [];
        final sendero = credit['senderoLine'] is Map
            ? Map<String, dynamic>.from(credit['senderoLine'] as Map)
            : <String, dynamic>{};
        final altura = credit['alturaLine'] is Map
            ? Map<String, dynamic>.from(credit['alturaLine'] as Map)
            : <String, dynamic>{};

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const KrediScreenTitle('Líneas y cuotas'),
            const SizedBox(height: 18),
            _WalletLineCard(
              title: KrediCreditPolicy.senderoName,
              amount: jDouble(sendero, ['availableUsd']),
              limit: jDouble(sendero, ['limitUsd']),
              subtitle: 'Tu línea principal · 0% inicial',
            ),
            if (jBool(altura, ['eligible'])) ...[
              const SizedBox(height: 10),
              _WalletLineCard(
                title: KrediCreditPolicy.alturaName,
                amount: jDouble(altura, ['availableUsd']),
                limit: jDouble(altura, ['limitUsd']),
                subtitle: 'Disponible porque estás al día',
                ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _summaryMetricCard('Actividad', '${tx.length}', KrediIcons.movements)),
                const SizedBox(width: 10),
                Expanded(child: _summaryMetricCard('Cuotas', '${jList(credit, ['installments']).length}', KrediIcons.payments)),
              ],
            ),
            const SizedBox(height: 14),
            KrediActionButton(
              icon: KrediIcons.movements,
              label: 'Ver movimientos',
              tone: KrediActionTone.secondary,
              expanded: true,
              onPressed: onOpenMovements,
            ),
          ],
        );
      },
    );
  }
}

class _WalletLineCard extends StatelessWidget {
  const _WalletLineCard({
    required this.title,
    required this.amount,
    required this.limit,
    required this.subtitle,
  });
  final String title;
  final double amount;
  final double limit;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KrediColors.softOrange,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD49C)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(color: KrediColors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const Icon(KrediIcons.chevron, color: KrediColors.orangeDeep),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'US\$ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: KrediColors.black, fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Límite US\$ ${limit.toStringAsFixed(2)} · $subtitle',
              style: const TextStyle(color: KrediColors.secondary, fontSize: 12),
            ),
          ],
        ),
      );
}

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppScope.of(context).api.promotions(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return KrediEmptyState(
            icon: KrediIcons.promotions,
            title: 'No pudimos cargar tus beneficios',
            message: snap.error.toString(),
          );
        }
        final items = snap.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return const KrediEmptyState(
            icon: KrediIcons.promotions,
            title: 'Sin promociones activas',
            message: 'Cuando haya un beneficio disponible aparecerá aquí.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const KrediScreenTitle('Beneficios para ti'),
            const SizedBox(height: 18),
            for (final item in items) ...[
              KrediOutlineCard(
                color: KrediColors.softCream,
                child: KrediMenuRow(
                  icon: KrediIcons.promotions,
                  title: _title(item),
                  subtitle: _promotionSubtitle(item),
                  iconColor: KrediColors.coral,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

Widget _summaryMetricCard(String label, String value, IconData icon) {
  return KrediOutlineCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: KrediColors.coral),
        const SizedBox(height: 16),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: KrediColors.secondary),
        ),
      ],
    ),
  );
}

String _promotionSubtitle(Map<String, dynamic> data) {
  final type = jString(data, ['discountType']).toUpperCase();
  final value = jDouble(data, ['discountValue']);
  if (value <= 0) return _subtitle(data);
  if (type.contains('PERCENT')) {
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% de descuento';
  }
  return 'US\$ ${value.toStringAsFixed(2)} de descuento';
}

String _title(Map<String, dynamic> data) {
  for (final key in const [
    'name',
    'title',
    'commercialName',
    'legalName',
    'fullName',
    'username',
    'invoiceNumber',
    'description',
    'status',
  ]) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return 'Registro #${data['id'] ?? ''}';
}

String _subtitle(Map<String, dynamic> data) {
  final values = <String>[];
  for (final key in const [
    'status',
    'email',
    'category',
    'phone',
    'createdAt',
    'updatedAt',
  ]) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      values.add(value.toString());
    }
    if (values.length == 2) break;
  }
  return values.isEmpty ? 'Toca para ver los detalles' : values.join(' · ');
}

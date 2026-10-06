import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../auth/forgot_password_screen.dart';
import '../auth/forgot_pin_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  late Future<List<Map<String, dynamic>>> future;
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    final scope = AppScope.of(context);
    future = scope.api.sessions();
    scope.lock.refreshCapabilities();
  }

  Future<void> reload() async {
    setState(() => future = AppScope.of(context).api.sessions());
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final lock = AppScope.of(context).lock;
    return AnimatedBuilder(
      animation: lock,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const KrediScreenTitle(
            'Seguridad de tu cuenta',
            subtitle: 'PIN, biometría y dispositivos.',
          ),
          const SizedBox(height: 18),
          KrediOutlineCard(
            child: Column(
              children: [
                KrediMenuRow(
                  icon: KrediIcons.biometric,
                  title: 'Acceso biométrico',
                  subtitle: lock.enabled
                      ? 'Protege Kredi+ con la biometría de este dispositivo'
                      : 'Usa Face ID, huella o biometría para desbloquear Kredi+',
                  trailing: Switch.adaptive(
                    value: lock.enabled,
                    onChanged: lock.authenticating
                        ? null
                        : (value) => _toggleBiometrics(value),
                  ),
                ),
                if (lock.enabled) ...[
                  const Divider(height: 1),
                  KrediMenuRow(
                    icon: KrediIcons.lock,
                    title: 'Bloqueo automático',
                    subtitle: 'Se bloquea al volver después de 1 minuto',
                    trailing: const Icon(
                      KrediIcons.confirm,
                      color: KrediColors.success,
                    ),
                    onTap: lock.lockNow,
                  ),
                ],
                if (lock.error != null && lock.error!.trim().isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          KrediIcons.error,
                          color: KrediColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lock.error!,
                            style: const TextStyle(
                              color: KrediColors.danger,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          KrediOutlineCard(
            color: const Color(0xFFFFFBF7),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  KrediIcons.shield,
                  color: KrediColors.orangeDeep,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kredi+ no recibe ni almacena tus datos biométricos. Face ID, huella o biometría se validan en el dispositivo.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: KrediColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KrediOutlineCard(
            child: Column(
              children: [
                KrediMenuRow(
                  icon: KrediIcons.password,
                  title: 'Cambiar contraseña',
                  subtitle: 'Crea una nueva contraseña',
                  onTap: () => _openPasswordRecovery(context),
                ),
                const Divider(height: 1),
                KrediMenuRow(
                  icon: KrediIcons.pin,
                  title: 'Cambiar PIN',
                  subtitle: 'Crea un nuevo PIN de 6 dígitos',
                  onTap: () => _openPinRecovery(context),
                ),
                const Divider(height: 1),
                const KrediMenuRow(
                  icon: KrediIcons.identityVerification,
                  title: 'Verificación de identidad',
                  subtitle:
                      'Las operaciones sensibles conservan su validación de seguridad',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const KrediSectionRow(title: 'Sesiones y dispositivos'),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snap.hasError) {
                return Text(
                  snap.error.toString(),
                  style: const TextStyle(color: KrediColors.danger),
                );
              }
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const KrediEmptyState(
                  icon: KrediIcons.devices,
                  title: 'Sin sesiones registradas',
                  message:
                      'Tus dispositivos aparecerán aquí cuando se registren nuevas sesiones.',
                );
              }
              return Column(
                children: [
                  for (final row in rows) ...[
                    KrediOutlineCard(
                      child: Row(
                        children: [
                          const Icon(
                            KrediIcons.smartphone,
                            color: KrediColors.coral,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  jString(
                                    row,
                                    ['deviceName'],
                                    'Dispositivo Kredi+',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  jString(row, ['createdAt']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: KrediColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _revoke(jString(row, ['id'])),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometrics(bool value) async {
    final scope = AppScope.of(context);
    final lock = scope.lock;
    lock.clearError();
    if (!value) {
      await lock.disableBiometrics();
      if (mounted) showKrediMessage(context, 'Acceso biométrico desactivado.');
      return;
    }

    String? pin;
    if (lock.hasKrediPinFallback) {
      pin = await _askForPin();
      if (pin == null) return;
    }
    final ok = await lock.enableBiometrics(krediPin: pin);
    if (!mounted) return;
    if (ok) {
      showKrediMessage(context, 'Acceso biométrico activado.');
    } else if (lock.error != null) {
      showKrediMessage(context, lock.error!);
    }
  }

  Future<String?> _askForPin() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirma tu PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa tu PIN Kredi+ de 6 dígitos antes de activar la biometría.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'PIN Kredi+',
                  prefixIcon: Icon(KrediIcons.pin),
                ),
                onSubmitted: (value) {
                  if (value.length == 6) Navigator.pop(dialogContext, value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length == 6) {
                  Navigator.pop(dialogContext, controller.text);
                }
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openPasswordRecovery(BuildContext context) async {
    final user = AppScope.of(context).auth.user!;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialIdentifier: user.username.isNotEmpty
              ? user.username
              : user.email,
        ),
      ),
    );
  }

  Future<void> _openPinRecovery(BuildContext context) async {
    final user = AppScope.of(context).auth.user!;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPinScreen(
          initialIdentifier: user.username.isNotEmpty
              ? user.username
              : user.email,
        ),
      ),
    );
    if (!mounted) return;
    await AppScope.of(context).lock.refreshPinFallback();
  }

  Future<void> _revoke(String id) async {
    if (id.isEmpty) return;
    try {
      await AppScope.of(context).api.revokeSession(id);
      if (!mounted) return;
      showKrediMessage(context, 'Sesión cerrada.');
      await reload();
    } catch (e) {
      if (mounted) showKrediMessage(context, e.toString());
    }
  }
}

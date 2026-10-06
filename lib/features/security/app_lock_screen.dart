import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_actions.dart';
import '../../shared/widgets/kredi_brand.dart';
import 'app_lock_controller.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pin = TextEditingController();
  final _focus = FocusNode();
  bool _pinMode = false;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoAuthenticate());
  }

  @override
  void dispose() {
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _autoAuthenticate() async {
    if (_autoPrompted || !mounted) return;
    _autoPrompted = true;
    final lock = AppScope.of(context).lock;
    if (!lock.locked || lock.authenticating) return;
    await lock.unlockWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lock = scope.lock;
    final user = scope.auth.user;
    return AnimatedBuilder(
      animation: lock,
      builder: (context, _) {
        final biometricName = lock.capabilities?.displayName ?? 'biometría';
        final biometricIcon = lock.capabilities?.hasFace == true
            ? Icons.face_retouching_natural_rounded
            : KrediIcons.biometric;
        return Scaffold(
        backgroundColor: const Color(0xFFFFFBF7),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: KrediBrand(height: 44)),
                    const SizedBox(height: 44),
                    Text(
                      _pinMode ? 'Ingresa tu PIN' : 'Desbloquea Kredi+',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        color: KrediColors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _pinMode
                          ? 'Usa tu PIN Kredi+ de 6 dígitos.'
                          : 'Usa $biometricName para continuar de forma segura.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: KrediColors.secondary,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                    if ((user?.fullName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user!.fullName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KrediColors.black,
                        ),
                      ),
                    ],
                    const SizedBox(height: 34),
                    if (!_pinMode) ...[
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'Desbloquear con $biometricName',
                          child: Material(
                            color: KrediColors.softOrange,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: lock.authenticating
                                  ? null
                                  : lock.unlockWithBiometrics,
                              child: SizedBox(
                                width: 132,
                                height: 132,
                                child: lock.authenticating
                                    ? const Center(
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        biometricIcon,
                                        size: 72,
                                        color: KrediColors.orangeDeep,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      KrediActionButton(
                        icon: biometricIcon,
                        label: 'Usar $biometricName',
                        onPressed: lock.authenticating
                            ? null
                            : lock.unlockWithBiometrics,
                        busy: lock.authenticating,
                        expanded: true,
                      ),
                      const SizedBox(height: 10),
                      if (lock.hasKrediPinFallback)
                        OutlinedButton.icon(
                          onPressed: lock.authenticating
                              ? null
                              : () {
                                  lock.clearError();
                                  setState(() => _pinMode = true);
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => _focus.requestFocus(),
                                  );
                                },
                          icon: const Icon(KrediIcons.pin),
                          label: const Text('Usar PIN Kredi+'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: lock.authenticating
                              ? null
                              : lock.unlockWithDeviceCredential,
                          icon: const Icon(KrediIcons.lock),
                          label: const Text('Usar bloqueo del dispositivo'),
                        ),
                    ] else ...[
                      _LocalPinInput(
                        controller: _pin,
                        focusNode: _focus,
                        enabled: !lock.authenticating,
                        onChanged: (_) {
                          lock.clearError();
                          setState(() {});
                        },
                        onSubmitted: (_) => _submitPin(lock),
                      ),
                      const SizedBox(height: 22),
                      KrediActionButton(
                        icon: KrediIcons.lock,
                        label: 'Desbloquear',
                        onPressed: _pin.text.length == 6
                            ? () => _submitPin(lock)
                            : null,
                        busy: lock.authenticating,
                        expanded: true,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _pin.clear();
                          lock.clearError();
                          setState(() => _pinMode = false);
                        },
                        icon: Icon(biometricIcon),
                        label: Text('Volver a usar $biometricName'),
                      ),
                    ],
                    if (lock.error != null && lock.error!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3EF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          lock.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8A2D19),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          KrediIcons.shield,
                          size: 18,
                          color: KrediColors.orangeDeep,
                        ),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '$biometricName se valida en el dispositivo. Kredi+ no recibe tus datos biométricos.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: KrediColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: lock.authenticating
                          ? null
                          : () async {
                              await lock.disableBiometrics();
                              await scope.auth.logout();
                            },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  Future<void> _submitPin(AppLockController lock) async {
    if (_pin.text.length != 6) return;
    final ok = await lock.unlockWithKrediPin(_pin.text);
    if (!ok && mounted) {
      _pin.clear();
      setState(() {});
      _focus.requestFocus();
    }
  }
}

class _LocalPinInput extends StatelessWidget {
  const _LocalPinInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final value = controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? focusNode.requestFocus : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final filled = index < value.length;
              return Container(
                width: 44,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: filled
                        ? KrediColors.orangeDeep
                        : KrediColors.border,
                    width: filled ? 1.5 : 1,
                  ),
                ),
                child: filled
                    ? const Text(
                        '•',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.001,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

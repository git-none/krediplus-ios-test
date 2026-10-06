import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_ui.dart';
import '../../core/icons/kredi_icons.dart';

enum _PinRecoveryStep { identify, confirmEmail, reset }

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key, this.initialIdentifier = ''});
  final String initialIdentifier;

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  late final TextEditingController identifier;
  final code = TextEditingController();
  final pin = TextEditingController();
  _PinRecoveryStep step = _PinRecoveryStep.identify;
  String maskedEmail = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    identifier = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    identifier.dispose();
    code.dispose();
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar PIN')),
    body: KrediAuthBackground(
      child: SafeArea(
        top: false,
        child: KrediResponsive(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              KrediSectionHeader(
                step == _PinRecoveryStep.reset
                    ? 'Crea un nuevo PIN'
                    : 'Recuperar PIN',
                subtitle: _subtitle,
              ),
              const SizedBox(height: 14),
              KrediSoftCard(
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: identifier,
                      enabled: step == _PinRecoveryStep.identify,
                      decoration: const InputDecoration(
                        labelText: 'Usuario, cédula o correo',
                        prefixIcon: Icon(KrediIcons.personSearch),
                      ),
                    ),
                    if (step == _PinRecoveryStep.confirmEmail) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Enviaremos el código a $maskedEmail',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (step == _PinRecoveryStep.reset) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
                          prefixIcon: Icon(KrediIcons.password),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Nuevo PIN de 6 dígitos',
                          prefixIcon: Icon(KrediIcons.pin),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              KrediActionButton(
                icon: switch (step) {
                  _PinRecoveryStep.identify => KrediIcons.personSearch,
                  _PinRecoveryStep.confirmEmail => KrediIcons.send,
                  _PinRecoveryStep.reset => KrediIcons.pin,
                },
                label: _buttonText,
                onPressed: _submit,
                busy: busy,
                expanded: true,
              ),
              if (step != _PinRecoveryStep.identify) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _restart,
                  child: const Text('Usar otra cuenta'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  String get _subtitle => switch (step) {
    _PinRecoveryStep.identify =>
      'Identifica tu cuenta para continuar.',
    _PinRecoveryStep.confirmEmail =>
      'Confirma el correo registrado antes de solicitar el código.',
    _PinRecoveryStep.reset =>
      'Escribe el código recibido y crea un nuevo PIN. Tu contraseña no será modificada.',
  };

  String get _buttonText => switch (step) {
    _PinRecoveryStep.identify => 'Buscar mi cuenta',
    _PinRecoveryStep.confirmEmail => 'Enviar código a este correo',
    _PinRecoveryStep.reset => 'Cambiar PIN',
  };

  void _restart() => setState(() {
    step = _PinRecoveryStep.identify;
    maskedEmail = '';
    code.clear();
    pin.clear();
  });

  Future<void> _submit() async {
    final id = identifier.text.trim();
    if (id.isEmpty) {
      showKrediMessage(
        context,
        'Ingresa tu usuario, cédula o correo registrado.',
      );
      return;
    }
    if (step == _PinRecoveryStep.reset &&
        (code.text.trim().length != 6 || pin.text.length != 6)) {
      showKrediMessage(context, 'Verifica el código y el PIN de 6 dígitos.');
      return;
    }
    setState(() => busy = true);
    try {
      final api = AppScope.of(context).api;
      switch (step) {
        case _PinRecoveryStep.identify:
          final result = await api.identifyRecoveryAccount(id);
          if (!mounted) return;
          final masked = (result['maskedEmail'] ?? '').toString().trim();
          if (masked.isEmpty) {
            throw const FormatException(
              'No fue posible identificar el correo de recuperación.',
            );
          }
          setState(() {
            maskedEmail = masked;
            step = _PinRecoveryStep.confirmEmail;
          });
          break;
        case _PinRecoveryStep.confirmEmail:
          await api.requestPinRecovery(id);
          if (!mounted) return;
          setState(() => step = _PinRecoveryStep.reset);
          showKrediMessage(context, 'Código enviado a $maskedEmail.');
          break;
        case _PinRecoveryStep.reset:
          await api.resetPinRecovery(
            identifier: id,
            code: code.text.trim(),
            newPin: pin.text,
          );
          if (!mounted) return;
          final scope = AppScope.of(context);
          await scope.auth.updateLocalPinVerifier(pin.text);
          await scope.lock.refreshPinFallback();
          if (!mounted) return;
          showKrediMessage(context, 'PIN actualizado correctamente.');
          Navigator.pop(context);
          break;
      }
    } catch (e) {
      if (mounted) showKrediMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_ui.dart';
import '../../core/icons/kredi_icons.dart';

enum _RecoveryStep { identify, confirmEmail, reset }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialIdentifier = ''});
  final String initialIdentifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController identifier;
  final code = TextEditingController();
  final password = TextEditingController();
  _RecoveryStep step = _RecoveryStep.identify;
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
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar contraseña')),
    body: KrediAuthBackground(
      child: SafeArea(
        top: false,
        child: KrediResponsive(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              KrediSectionHeader(
                step == _RecoveryStep.reset
                    ? 'Crea una nueva contraseña'
                    : 'Recuperar contraseña',
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
                      enabled: step == _RecoveryStep.identify,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Usuario, cédula o correo',
                        prefixIcon: Icon(KrediIcons.personSearch),
                      ),
                    ),
                    if (step == _RecoveryStep.confirmEmail) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Enviaremos el código a $maskedEmail',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (step == _RecoveryStep.reset) ...[
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
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contraseña',
                          prefixIcon: Icon(KrediIcons.lock),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              KrediActionButton(
                icon: switch (step) {
                  _RecoveryStep.identify => KrediIcons.personSearch,
                  _RecoveryStep.confirmEmail => KrediIcons.send,
                  _RecoveryStep.reset => KrediIcons.password,
                },
                label: _buttonText,
                onPressed: _submit,
                busy: busy,
                expanded: true,
              ),
              if (step != _RecoveryStep.identify) ...[
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
    _RecoveryStep.identify =>
      'Identifica tu cuenta para continuar.',
    _RecoveryStep.confirmEmail =>
      'Confirma el correo registrado antes de solicitar el código.',
    _RecoveryStep.reset =>
      'Escribe el código recibido y crea una nueva contraseña. Tu PIN no será modificado.',
  };

  String get _buttonText => switch (step) {
    _RecoveryStep.identify => 'Buscar mi cuenta',
    _RecoveryStep.confirmEmail => 'Enviar código a este correo',
    _RecoveryStep.reset => 'Cambiar contraseña',
  };

  void _restart() => setState(() {
    step = _RecoveryStep.identify;
    maskedEmail = '';
    code.clear();
    password.clear();
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
    if (step == _RecoveryStep.reset &&
        (code.text.trim().length != 6 || password.text.length < 8)) {
      showKrediMessage(
        context,
        'Verifica el código y escribe una contraseña válida.',
      );
      return;
    }

    setState(() => busy = true);
    try {
      final api = AppScope.of(context).api;
      switch (step) {
        case _RecoveryStep.identify:
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
            step = _RecoveryStep.confirmEmail;
          });
          break;
        case _RecoveryStep.confirmEmail:
          await api.requestPasswordRecovery(id);
          if (!mounted) return;
          setState(() => step = _RecoveryStep.reset);
          showKrediMessage(context, 'Código enviado a $maskedEmail.');
          break;
        case _RecoveryStep.reset:
          await api.resetPasswordRecovery(
            identifier: id,
            code: code.text.trim(),
            newPassword: password.text,
          );
          if (!mounted) return;
          showKrediMessage(context, 'Contraseña actualizada correctamente.');
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

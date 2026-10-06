import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/platform/external_links.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _code = TextEditingController();
  bool _initialized = false;
  bool _busy = false;
  bool _codeSent = false;
  bool _confirmed = false;
  String _email = '';
  String? _message;
  bool _messageIsError = false;
  int? _requestId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _email = AppScope.of(context).auth.user?.email.trim() ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_email.isEmpty || !_email.contains('@')) {
      setState(() {
        _message = 'Tu cuenta no tiene un correo válido para verificar la solicitud.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      final response = await AppScope.of(context).api.requestAccountDeletion(
        email: _email,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _message = (response['message'] ??
                'Si el correo corresponde a tu cuenta, recibirás un código de 6 dígitos.')
            .toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _cleanError(e);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() {
        _message = 'Ingresa el código de 6 dígitos enviado a tu correo.';
        _messageIsError = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      final response = await AppScope.of(context).api.confirmAccountDeletion(
        email: _email,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _requestId = int.tryParse(response['requestId']?.toString() ?? '');
        _message = (response['message'] ?? 'Solicitud registrada correctamente.').toString();
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _cleanError(e);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWeb() async {
    try {
      await ExternalLinks.open(AppConfig.accountDeletionUrl);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la página de eliminación.')),
      );
    }
  }

  String _cleanError(Object error) {
    final value = error.toString().trim();
    if (value.isEmpty) return 'No fue posible completar la solicitud.';
    return value.replaceFirst(RegExp(r'^(ApiException|Exception):\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar cuenta')),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const KrediScreenTitle(
              'Solicitar eliminación',
              subtitle: 'Verifica tu correo para registrar la solicitud desde Kredi+.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KrediColors.softError,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF5C7C2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(KrediIcons.delete, color: KrediColors.danger),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Esta solicitud no es lo mismo que cerrar sesión. Kredi+ revisará la eliminación y podrá conservar la información que deba mantenerse por operaciones pendientes, obligaciones aplicables o auditoría. Tus compras, cuotas y pagos no se borran automáticamente al enviar la solicitud.',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            KrediOutlineCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Correo de tu cuenta',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _email.isEmpty ? 'No disponible' : _email,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El código se enviará únicamente al correo registrado en tu cuenta.',
                    style: TextStyle(fontSize: 12.5, color: KrediColors.secondary, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!_confirmed) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _requestCode,
                icon: _busy && !_codeSent
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(KrediIcons.email),
                label: Text(_codeSent ? 'Reenviar código' : 'Enviar código de verificación'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    hintText: '123456',
                    counterText: '',
                  ),
                  onSubmitted: (_) {
                    if (!_busy) _confirm();
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: KrediColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _confirm,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(KrediIcons.confirm),
                  label: const Text('Confirmar solicitud de eliminación'),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KrediColors.softGreen,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFE8D4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(KrediIcons.success, color: KrediColors.success),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Solicitud registrada',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (_requestId != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Número de solicitud: #$_requestId',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Estado: Pendiente de revisión',
                      style: TextStyle(color: KrediColors.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await AppScope.of(context).auth.logout();
                        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                icon: const Icon(KrediIcons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _messageIsError ? KrediColors.softError : KrediColors.softBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError ? KrediColors.danger : KrediColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _openWeb,
              icon: const Icon(KrediIcons.website),
              label: const Text('También puedes solicitarla en krediplus.org'),
            ),
          ],
        ),
      ),
    );
  }
}

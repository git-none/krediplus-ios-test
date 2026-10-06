import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_scope.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../../core/icons/kredi_icons.dart';

class RegistrationVerificationScreen extends StatefulWidget {
  const RegistrationVerificationScreen({super.key});
  @override
  State<RegistrationVerificationScreen> createState() =>
      _RegistrationVerificationScreenState();
}

class _RegistrationVerificationScreenState
    extends State<RegistrationVerificationScreen> with WidgetsBindingObserver {
  final documentNumber = TextEditingController();
  final picker = ImagePicker();
  File? front;
  File? back;
  File? selfie;
  bool busy = false;
  bool waiting = false;
  String signature = '';
  String status = 'NOT_SUBMITTED';
  String? rejectionReason;
  bool foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = AppScope.of(context).auth.pendingRegistrationStatus
          .trim()
          .toUpperCase();
      if (current.isNotEmpty) {
        setState(() => status = current);
      }
      if (current == 'PENDING') {
        _startWaiting();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    waiting = false;
    documentNumber.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Conserva una sola rutina de escucha. En segundo plano no abre nuevas
    // solicitudes; al volver al frente retoma con la misma firma/cursor.
    foreground = state == AppLifecycleState.resumed;
  }

  Future<File?> _capture({required bool selfieMode}) async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: selfieMode
          ? CameraDevice.front
          : CameraDevice.rear,
      imageQuality: 88,
      maxWidth: 2200,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _send() async {
    final scope = AppScope.of(context);
    final uid = scope.auth.pendingRegistrationUserId;
    final token = scope.auth.pendingRegistrationToken;
    if (uid == null || token == null || token.isEmpty) {
      _message(
        'La autorización de registro venció. Inicia sesión para continuar.',
      );
      return;
    }
    if (documentNumber.text.trim().isEmpty || front == null || selfie == null) {
      _message('Ingresa tu documento y toma la foto frontal y la selfie.');
      return;
    }
    setState(() => busy = true);
    try {
      await scope.api.submitRegistrationVerification(
        userId: uid,
        registrationToken: token,
        documentNumber: documentNumber.text,
        front: front!,
        back: back,
        selfie: selfie!,
      );
      if (!mounted) return;
      scope.auth.updatePendingRegistrationStatus('PENDING');
      setState(() {
        busy = false;
        status = 'PENDING';
      });
      _message(
        'Documentos recibidos. Te avisaremos al terminar la revisión.',
      );
      _startWaiting();
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        _message(e.toString());
      }
    }
  }

  void _startWaiting() {
    if (waiting) return;
    waiting = true;
    unawaited(_watchStatus());
  }

  Future<void> _watchStatus() async {
    var retry = 0;
    while (mounted && waiting) {
      if (!foreground) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      }
      final scope = AppScope.of(context);
      final uid = scope.auth.pendingRegistrationUserId;
      final token = scope.auth.pendingRegistrationToken;
      if (uid == null || token == null || token.isEmpty) return;
      try {
        final result = await scope.api.waitRegistrationStatus(
          userId: uid,
          registrationToken: token,
          signature: signature,
          waitSeconds: 18,
        );
        if (!mounted || !waiting) return;
        if (!foreground) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        retry = 0;
        signature = result['signature']?.toString() ?? signature;
        final nextStatus =
            result['verificationStatus']?.toString().toUpperCase() ?? status;
        final reason = result['reviewReason']?.toString().trim();
        scope.auth.updatePendingRegistrationStatus(nextStatus);
        setState(() {
          status = nextStatus;
          rejectionReason = reason == null || reason.isEmpty ? null : reason;
        });

        if (nextStatus == 'VERIFIED' &&
            result['accountVerified'] == true &&
            (result['pinChallengeToken']?.toString().isNotEmpty ?? false)) {
          waiting = false;
          scope.auth.completeRegistrationApproval(
            userId: uid,
            pinChallengeToken: result['pinChallengeToken'].toString(),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          _message('Registro aprobado. Ingresa tu PIN para entrar a Kredi+.');
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        if (nextStatus == 'REJECTED') {
          waiting = false;
          return;
        }
      } catch (_) {
        if (!mounted || !waiting) return;
        retry = (retry + 1).clamp(1, 5).toInt();
        await Future<void>.delayed(Duration(seconds: retry * 2));
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceFirst('ApiException: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'PENDING';
    final isRejected = status == 'REJECTED';
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu identidad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            KrediScreenTitle(
              isPending ? 'Revisión en curso' : 'Último paso',
              subtitle: isPending
                  ? 'La revisión se actualiza automáticamente.'
                  : isRejected
                  ? 'Debes reenviar la verificación.'
                  : 'Envía tu documento y una selfie.',
            ),
            const SizedBox(height: 20),
            if (isPending) ...[
              _LiveStatusCard(status: status),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text(
                'Al aprobarse, continuarás automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KrediColors.secondary, height: 1.4),
              ),
            ] else if (isRejected) ...[
              _LiveStatusCard(status: status, reason: rejectionReason),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  AppScope.of(context).auth.clearPendingRegistration();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Volver al inicio de sesión'),
              ),
            ] else ...[
              TextField(
                controller: documentNumber,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Cédula o documento',
                  prefixIcon: Icon(KrediIcons.identity),
                ),
              ),
              const SizedBox(height: 16),
              _CaptureTile(
                title: 'Frente del documento',
                done: front != null,
                onTap: busy
                    ? null
                    : () async {
                        final f = await _capture(selfieMode: false);
                        if (f != null && mounted) setState(() => front = f);
                      },
              ),
              const SizedBox(height: 10),
              _CaptureTile(
                title: 'Reverso del documento (opcional)',
                done: back != null,
                onTap: busy
                    ? null
                    : () async {
                        final f = await _capture(selfieMode: false);
                        if (f != null && mounted) setState(() => back = f);
                      },
              ),
              const SizedBox(height: 10),
              _CaptureTile(
                title: 'Selfie actual',
                done: selfie != null,
                onTap: busy
                    ? null
                    : () async {
                        final f = await _capture(selfieMode: true);
                        if (f != null && mounted) setState(() => selfie = f);
                      },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: KrediActionButton(
                  icon: KrediIcons.send,
                  label: 'Enviar a revisión',
                  onPressed: _send,
                  busy: busy,
                  expanded: true,
                  tone: KrediActionTone.dark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({required this.status, this.reason});
  final String status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'REJECTED';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: rejected ? const Color(0xFFFFF1F0) : KrediColors.softCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rejected ? const Color(0xFFF5B7B1) : KrediColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? KrediIcons.error : KrediIcons.sync,
            color: rejected ? Colors.red.shade700 : KrediColors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rejected ? 'Revisión no aprobada' : 'Conectado con Kredi+',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  rejected
                      ? (reason?.isNotEmpty == true
                            ? reason!
                            : 'Consulta el motivo con Administración antes de volver a enviar.')
                      : 'Esperando la decisión de Administración…',
                  style: const TextStyle(color: KrediColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.title,
    required this.done,
    required this.onTap,
  });
  final String title;
  final bool done;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE8E8E8)),
    ),
    leading: Icon(
      done ? KrediIcons.success : KrediIcons.camera,
      color: done ? Colors.green : KrediColors.coral,
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: const Icon(KrediIcons.chevron),
    onTap: onTap,
  );
}

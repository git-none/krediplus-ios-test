import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';

class BodegaEvidenceScreen extends StatefulWidget {
  const BodegaEvidenceScreen({super.key, this.initialCode = ''});
  final String initialCode;

  @override
  State<BodegaEvidenceScreen> createState() => _BodegaEvidenceScreenState();
}

class _BodegaEvidenceScreenState extends State<BodegaEvidenceScreen> {
  final codeController = TextEditingController();
  final picker = ImagePicker();
  Map<String, dynamic>? application;
  File? face;
  File? document;
  File? establishment;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    codeController.text = widget.initialCode.trim().toUpperCase();
    if (codeController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final code = codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _message('Ingresa el código de continuación mostrado en la web.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await AppScope.of(context).api.bodegaApplication(code);
      if (!mounted) return;
      setState(() {
        application = data;
        busy = false;
        codeController.text = (data['continuationCode'] ?? code).toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<File?> _capture({required bool frontCamera}) async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          frontCamera ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 88,
      maxWidth: 2200,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _submit() async {
    if (face == null || document == null || establishment == null) {
      _message('Debes tomar las tres fotografías antes de enviar.');
      return;
    }
    setState(() => busy = true);
    try {
      final data = await AppScope.of(context).api.submitBodegaEvidence(
        code: codeController.text,
        face: face!,
        document: document!,
        establishment: establishment!,
      );
      if (!mounted) return;
      setState(() {
        application = data;
        face = null;
        document = null;
        establishment = null;
        busy = false;
      });
      _message('Evidencias enviadas. La bodega quedó en revisión.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      _message(e.toString());
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceFirst('ApiException: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = application;
    final status = (data?['status'] ?? '').toString().toUpperCase();
    final canCapture = data != null &&
        const {'EVIDENCE_PENDING', 'NEEDS_CORRECTION'}.contains(status);
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de bodega')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const KrediScreenTitle(
              'Continúa en la aplicación',
              subtitle:
                  'Las evidencias se toman directamente con la cámara. No necesitas volver a llenar los datos de la bodega.',
            ),
            const SizedBox(height: 18),
            if (data == null) ...[
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código de continuación',
                  hintText: 'KPBREG-XXXXXXXXXX',
                  prefixIcon: Icon(KrediIcons.qr),
                ),
              ),
              const SizedBox(height: 14),
              KrediActionButton(
                icon: KrediIcons.search,
                label: 'Buscar solicitud',
                onPressed: busy ? null : _load,
                busy: busy,
                expanded: true,
                tone: KrediActionTone.dark,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: KrediColors.danger)),
              ],
            ] else ...[
              _ApplicationSummary(data: data),
              const SizedBox(height: 16),
              if (status == 'NEEDS_CORRECTION') ...[
                _CorrectionCard(data: data),
                const SizedBox(height: 16),
              ],
              if (canCapture) ...[
                _CaptureTile(
                  title: 'Foto del rostro',
                  subtitle: 'Mira de frente a la cámara y procura buena iluminación.',
                  done: face != null,
                  onTap: busy
                      ? null
                      : () async {
                          final f = await _capture(frontCamera: true);
                          if (mounted && f != null) setState(() => face = f);
                        },
                ),
                const SizedBox(height: 10),
                _CaptureTile(
                  title: 'Foto de la cédula o RIF',
                  subtitle: 'El documento debe verse completo y ser legible.',
                  done: document != null,
                  onTap: busy
                      ? null
                      : () async {
                          final f = await _capture(frontCamera: false);
                          if (mounted && f != null) setState(() => document = f);
                        },
                ),
                const SizedBox(height: 10),
                _CaptureTile(
                  title: 'Foto del establecimiento',
                  subtitle: 'Fotografía la fachada o entrada de la bodega.',
                  done: establishment != null,
                  onTap: busy
                      ? null
                      : () async {
                          final f = await _capture(frontCamera: false);
                          if (mounted && f != null) {
                            setState(() => establishment = f);
                          }
                        },
                ),
                const SizedBox(height: 22),
                KrediActionButton(
                  icon: KrediIcons.send,
                  label: status == 'NEEDS_CORRECTION'
                      ? 'Reenviar a revisión'
                      : 'Enviar a revisión',
                  onPressed: busy ? null : _submit,
                  busy: busy,
                  expanded: true,
                  tone: KrediActionTone.dark,
                ),
              ] else ...[
                _StatusCard(status: status, label: data['statusLabel']?.toString()),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : _load,
                  icon: const Icon(KrediIcons.sync),
                  label: const Text('Actualizar estado'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ApplicationSummary extends StatelessWidget {
  const _ApplicationSummary({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KrediColors.softCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KrediColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Solicitud encontrada',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(data['storeName']?.toString() ?? 'Bodega'),
            const SizedBox(height: 4),
            Text(
              '${data['ownerName'] ?? ''} · ${data['municipality'] ?? ''} · ${data['community'] ?? ''}',
              style: const TextStyle(color: KrediColors.secondary),
            ),
          ],
        ),
      );
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final raw = data['correctionReasons'];
    final reasons = raw is List
        ? raw.whereType<Map>().map((e) => e['label']?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];
    final note = data['correctionNotes']?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D39B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Debes corregir', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $reason'),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(color: KrediColors.secondary)),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, this.label});
  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'APPROVED';
    final rejected = status == 'REJECTED';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: approved
            ? const Color(0xFFEFF8F1)
            : rejected
                ? const Color(0xFFFFF1F0)
                : KrediColors.softCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KrediColors.border),
      ),
      child: Row(
        children: [
          Icon(approved ? KrediIcons.success : rejected ? KrediIcons.error : KrediIcons.sync),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label?.isNotEmpty == true ? label! : 'Solicitud en revisión',
              style: const TextStyle(fontWeight: FontWeight.w600),
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
    required this.subtitle,
    required this.done,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KrediColors.border),
        ),
        leading: Icon(
          done ? KrediIcons.success : KrediIcons.camera,
          color: done ? Colors.green : KrediColors.coral,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(done ? 'Foto lista. Toca para repetirla.' : subtitle),
        trailing: const Icon(KrediIcons.forward),
      );
}

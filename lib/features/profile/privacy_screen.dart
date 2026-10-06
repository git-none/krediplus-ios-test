import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/platform/external_links.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _openPolicy(BuildContext context) async {
    try {
      await ExternalLinks.open(AppConfig.privacyUrl);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la política de privacidad.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const KrediScreenTitle(
              'Tu información y Kredi+',
              subtitle: 'Consulta los controles principales de privacidad de tu cuenta.',
            ),
            const SizedBox(height: 18),
            KrediOutlineCard(
              child: Column(
                children: const [
                  _PrivacyItem(
                    icon: KrediIcons.identityVerification,
                    title: 'Datos de cuenta',
                    text: 'Kredi+ utiliza los datos necesarios para identificar tu cuenta, operar compras, cuotas, pagos, soporte y verificación.',
                  ),
                  Divider(height: 1),
                  _PrivacyItem(
                    icon: KrediIcons.biometric,
                    title: 'Biometría del dispositivo',
                    text: 'Face ID, huella o biometría se validan mediante el sistema del dispositivo. Kredi+ no guarda imágenes ni plantillas biométricas.',
                  ),
                  Divider(height: 1),
                  _PrivacyItem(
                    icon: KrediIcons.delete,
                    title: 'Eliminar tu cuenta',
                    text: 'Puedes iniciar una solicitud de eliminación directamente desde Configuración o Mi cuenta.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openPolicy(context),
              icon: const Icon(KrediIcons.privacy),
              label: const Text('Ver política de privacidad completa'),
            ),
            const SizedBox(height: 10),
            const Text(
              'La política publicada en krediplus.org contiene la información completa y vigente sobre tratamiento, conservación y solicitudes relacionadas con tus datos.',
              style: TextStyle(fontSize: 12.5, color: KrediColors.secondary, height: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Icon(icon, color: KrediColors.coral, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(fontSize: 12.5, color: KrediColors.secondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

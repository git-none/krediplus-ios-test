import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/platform/external_links.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../shell/app_destination.dart';
import '../profile/privacy_screen.dart';
import '../profile/account_deletion_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.onOpen});

  final ValueChanged<AppDestination> onOpen;

  Future<void> _openWeb(BuildContext context, String url) async {
    try {
      await ExternalLinks.open(url);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const KrediScreenTitle('Ayuda'),
        const SizedBox(height: 16),
        KrediOutlineCard(
          child: Column(
            children: [
              KrediMenuRow(
                icon: KrediIcons.website,
                title: 'Nuestra página web',
                subtitle: 'krediplus.org',
                onTap: () => _openWeb(context, AppConfig.websiteUrl),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.faq,
                title: 'FAQ',
                subtitle: 'Preguntas frecuentes sobre Kredi+.',
                onTap: () => _openWeb(context, AppConfig.faqUrl),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.guide,
                title: 'Cómo empezar',
                subtitle: 'Conoce cómo usar Kredi+.',
                onTap: () => _openWeb(context, AppConfig.gettingStartedUrl),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.join,
                title: 'Únete a Kredi+',
                subtitle: 'Conoce nuestras oportunidades.',
                onTap: () => _openWeb(context, AppConfig.joinUsUrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        KrediOutlineCard(
          child: Column(
            children: [
              KrediMenuRow(
                icon: KrediIcons.notifications,
                title: 'Notificaciones',
                onTap: () => onOpen(AppDestination.notifications),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.shield,
                title: 'Seguridad',
                onTap: () => onOpen(AppDestination.security),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.privacy,
                title: 'Política de privacidad',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.delete,
                title: 'Eliminar cuenta',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountDeletionScreen()),
                ),
              ),
              const Divider(height: 1),
              KrediMenuRow(
                icon: KrediIcons.info,
                title: 'Sobre Kredi+',
                subtitle:
                    'Versión ${AppConfig.versionName}+${AppConfig.versionCode}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

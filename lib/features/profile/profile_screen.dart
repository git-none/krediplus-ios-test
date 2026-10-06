import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../shell/app_destination.dart';
import 'edit_profile_screen.dart';
import 'privacy_screen.dart';
import 'account_deletion_screen.dart';
import '../stores/bodega_evidence_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onOpen,
  });

  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Text(
          'Mi cuenta',
          style: TextStyle(fontSize: 20, height: 1.05, fontWeight: FontWeight.w600, letterSpacing: 0),
        ),
        const SizedBox(height: 24),
        const KrediSectionRow(title: 'Cuenta'),
        const SizedBox(height: 8),
        KrediMenuRow(
          icon: KrediIcons.person,
          title: 'Perfil y contacto',
          subtitle: 'Datos personales, ubicación y correo.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
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
          title: 'Privacidad',
          subtitle: 'Consulta cómo Kredi+ protege y trata tus datos.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
        ),
        const Divider(height: 1),
        KrediMenuRow(
          icon: KrediIcons.delete,
          iconColor: KrediColors.danger,
          title: 'Eliminar cuenta',
          subtitle: 'Solicita la eliminación de tu cuenta y datos asociados.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountDeletionScreen())),
        ),
        const SizedBox(height: 24),
        const KrediSectionRow(title: 'Más'),
        const SizedBox(height: 8),
        KrediMenuRow(
          icon: KrediIcons.storefront,
          title: 'Registro de bodega',
          subtitle: 'Continúa aquí el levantamiento iniciado en la web.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BodegaEvidenceScreen()),
          ),
        ),
        const Divider(height: 1),
        KrediMenuRow(
          icon: KrediIcons.settings,
          title: 'Configuración',
          onTap: () => onOpen(AppDestination.settings),
        ),
        const Divider(height: 1),
        KrediMenuRow(
          icon: KrediIcons.movements,
          title: 'Actividad',
          subtitle: 'Consulta tus movimientos en un solo lugar.',
          onTap: () => onOpen(AppDestination.movements),
        ),
        const Divider(height: 1),
        KrediMenuRow(
          icon: KrediIcons.info,
          title: 'Ayuda e información',
          subtitle: 'Versión ${AppConfig.versionName}',
          onTap: () => onOpen(AppDestination.help),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: scope.auth.logout,
          icon: const Icon(KrediIcons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

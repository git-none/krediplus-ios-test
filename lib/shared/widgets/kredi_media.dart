import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/icons/kredi_icons.dart';

class KrediMedia {
  static Future<void> openImage(
    BuildContext context,
    String rawUrl, {
    String title = 'Imagen',
  }) async {
    final url = AppConfig.publicUrl(rawUrl);
    if (url.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _KrediImageViewer(url: url, title: title),
      ),
    );
  }
}

class KrediProofButton extends StatelessWidget {
  const KrediProofButton({
    super.key,
    required this.url,
    this.label = 'Ver comprobante',
    this.title = 'Comprobante',
    this.compact = false,
  });

  final String url;
  final String label;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return compact
        ? TextButton.icon(
            onPressed: () => KrediMedia.openImage(context, url, title: title),
            icon: const Icon(KrediIcons.image, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: () => KrediMedia.openImage(context, url, title: title),
            icon: const Icon(KrediIcons.image),
            label: Text(label),
          );
  }
}

class _KrediImageViewer extends StatelessWidget {
  const _KrediImageViewer({required this.url, required this.title});
  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KrediColors.black,
      appBar: AppBar(
        backgroundColor: KrediColors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: .75,
          maxScale: 5,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              width: double.infinity,
              progressIndicatorBuilder: (_, _, progress) => Center(
                child: CircularProgressIndicator(
                  value: progress.progress,
                  color: KrediColors.orange,
                ),
              ),
              errorWidget: (_, _, _) => const Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      KrediIcons.brokenImage,
                      color: Colors.white70,
                      size: 46,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No se pudo cargar esta imagen. Actualiza la pantalla para obtener un enlace nuevo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

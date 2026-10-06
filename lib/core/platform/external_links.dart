import 'package:flutter/services.dart';

/// Abre enlaces HTTPS mediante Android sin añadir otra dependencia al proyecto.
class ExternalLinks {
  const ExternalLinks._();

  static const MethodChannel _channel = MethodChannel(
    'com.krediplus.nativeapp/external_links',
  );

  static Future<void> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Enlace no válido');
    }
    await _channel.invokeMethod<void>('openUrl', {'url': uri.toString()});
  }
}

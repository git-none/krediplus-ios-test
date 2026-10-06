class AppConfig {
  static const String appName = 'Kredi+';
  static const String versionName = '2.2.23';
  static const int versionCode = 48;
  static const String releaseName =
      'Kredi+ Mobile 2.2.23+48 · onboarding responsive + niveles 2/4/6/8/10/12 · Flutter';



  static const String websiteUrl = 'https://krediplus.org/';
  static const String faqUrl = 'https://krediplus.org/preguntas-frecuentes';
  static const String gettingStartedUrl = 'https://krediplus.org/usuarios';
  static const String joinUsUrl = 'https://krediplus.org/empleos';
  static const String privacyUrl = 'https://krediplus.org/privacidad';
  static const String accountDeletionUrl = 'https://krediplus.org/eliminar-cuenta';
  static const String accountDeletionApiUrl = 'https://api.krediplus.org/account-deletion.php';

  static const String apiBaseUrl = String.fromEnvironment(
    'KREDI_API_BASE_URL',
    defaultValue: 'https://api.krediplus.org/api/v1',
  );

  static String publicUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    final origin = apiBaseUrl.split('/api/').first;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw
          .replaceFirst('http://127.0.0.1:8080', origin)
          .replaceFirst('http://localhost:8080', origin);
    }
    return raw.startsWith('/') ? '$origin$raw' : '$origin/$raw';
  }
}

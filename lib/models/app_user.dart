import '../core/utils/json_read.dart';

enum UserRole { beneficiary }

class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String verificationStatus;
  final String accountStatus;
  final Map<String, dynamic> raw;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.verificationStatus,
    required this.accountStatus,
    required this.raw,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roleRaw = jString(json, ['role'], 'BENEFICIARY').trim().toUpperCase();
    if (roleRaw != 'BENEFICIARY' && roleRaw != 'BENEFICIARIO') {
      throw const FormatException(
        'Este perfil es exclusivo de Kredi+ para PC.',
      );
    }
    final rawFullName = jString(json, ['fullName', 'full_name']).trim();
    final fullNameParts = rawFullName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final fullNameIsPlaceholder = fullNameParts.isNotEmpty &&
        fullNameParts.every(
          (part) => const {
            'none',
            'null',
            'undefined',
            'n/a',
            'nan',
          }.contains(part.toLowerCase()),
        );
    final fullName = fullNameIsPlaceholder ? '' : rawFullName;
    const placeholders = {
      'none',
      'null',
      'undefined',
      'n/a',
      'nan',
    };
    final composedName = [
      jString(json, ['firstName', 'first_name']),
      jString(json, ['secondName', 'middleName', 'second_name']),
      jString(json, ['lastName', 'last_name']),
      jString(json, ['secondLastName', 'second_last_name']),
    ]
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              !placeholders.contains(part.toLowerCase()),
        )
        .join(' ')
        .trim();
    return AppUser(
      id: jInt(json, ['id']),
      username: jString(json, ['username']),
      fullName: fullName.isNotEmpty ? fullName : (composedName.isNotEmpty ? composedName : 'Usuario'),
      email: jString(json, ['email']),
      phone: jString(json, ['phone']),
      role: UserRole.beneficiary,
      verificationStatus: jString(json, [
        'verificationStatus',
        'verification_status',
      ], 'NOT_SUBMITTED'),
      accountStatus: jString(json, [
        'accountStatus',
        'account_status',
      ], 'ACTIVE'),
      raw: json,
    );
  }

  String get roleLabel => 'Beneficiario';
}

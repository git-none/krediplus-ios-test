import '../utils/json_read.dart';

class KrediLevelRule {
  const KrediLevelRule({
    required this.level,
    required this.name,
    required this.senderoLimitUsd,
    required this.alturaLimitUsd,
    required this.maxInstallments,
    required this.completedPaymentsRequired,
    required this.completedPurchasesRequired,
    required this.minimumActiveDays,
    required this.minimumPunctuality,
  });

  final int level;
  final String name;
  final double senderoLimitUsd;
  final double alturaLimitUsd;
  final int maxInstallments;
  final int completedPaymentsRequired;
  final int completedPurchasesRequired;
  final int minimumActiveDays;
  final double minimumPunctuality;

  Map<String, dynamic> toJson() => {
        'level': level,
        'name': name,
        'completedPaymentsRequired': completedPaymentsRequired,
        'completedPurchasesRequired': completedPurchasesRequired,
        'minimumActiveDays': minimumActiveDays,
        'minimumPunctuality': minimumPunctuality,
        'creditMultiplier': level,
        'downPaymentPercent': 0.0,
        'baseAmountUsd': senderoLimitUsd,
        'senderoLimitUsd': senderoLimitUsd,
        'alturaLimitUsd': alturaLimitUsd,
        'maxInstallments': maxInstallments,
      };
}

/// Política visible de líneas Kredi+.
///
/// El backend debe aplicar las mismas reglas como fuente autoritativa. Esta
/// clase evita que la app muestre nombres, iniciales o límites heredados que ya
/// no forman parte del producto vigente.
class KrediCreditPolicy {
  static const String senderoName = 'Kredi Sendero';
  static const String alturaName = 'Kredi Altura';
  static const double initialPercent = 0;
  static const int maximumInstallments = 12;

  static const List<KrediLevelRule> levels = [
    KrediLevelRule(
      level: 1,
      name: 'Santa Ana',
      senderoLimitUsd: 60,
      alturaLimitUsd: 0,
      maxInstallments: 2,
      completedPaymentsRequired: 0,
      completedPurchasesRequired: 0,
      minimumActiveDays: 0,
      minimumPunctuality: 0,
    ),
    KrediLevelRule(
      level: 2,
      name: 'El Ávila',
      senderoLimitUsd: 120,
      alturaLimitUsd: 60,
      maxInstallments: 4,
      completedPaymentsRequired: 8,
      completedPurchasesRequired: 2,
      minimumActiveDays: 45,
      minimumPunctuality: 95,
    ),
    KrediLevelRule(
      level: 3,
      name: 'Autana',
      senderoLimitUsd: 200,
      alturaLimitUsd: 90,
      maxInstallments: 6,
      completedPaymentsRequired: 20,
      completedPurchasesRequired: 5,
      minimumActiveDays: 90,
      minimumPunctuality: 97,
    ),
    KrediLevelRule(
      level: 4,
      name: 'Auyantepuy',
      senderoLimitUsd: 300,
      alturaLimitUsd: 120,
      maxInstallments: 8,
      completedPaymentsRequired: 38,
      completedPurchasesRequired: 8,
      minimumActiveDays: 150,
      minimumPunctuality: 98,
    ),
    KrediLevelRule(
      level: 5,
      name: 'Pico Bolívar',
      senderoLimitUsd: 450,
      alturaLimitUsd: 160,
      maxInstallments: 10,
      completedPaymentsRequired: 62,
      completedPurchasesRequired: 12,
      minimumActiveDays: 210,
      minimumPunctuality: 99,
    ),
    KrediLevelRule(
      level: 6,
      name: 'Salto Ángel',
      senderoLimitUsd: 600,
      alturaLimitUsd: 200,
      maxInstallments: 12,
      completedPaymentsRequired: 95,
      completedPurchasesRequired: 18,
      minimumActiveDays: 300,
      minimumPunctuality: 99,
    ),
  ];

  static KrediLevelRule ruleFor(int rawLevel) =>
      levels[rawLevel.clamp(1, levels.length).toInt() - 1];

  static KrediLevelRule? nextRuleFor(int rawLevel) {
    final level = rawLevel.clamp(1, levels.length).toInt();
    return level >= levels.length ? null : levels[level];
  }

  static List<Map<String, dynamic>> get levelRules =>
      levels.map((rule) => rule.toJson()).toList(growable: false);

  static bool _isPending(Map<String, dynamic> installment) {
    final status = jString(installment, ['status']).toUpperCase();
    return !const {
      'PAID',
      'PAGADO',
      'COMPLETED',
      'COMPLETADO',
      'CANCELLED',
      'CANCELED',
    }.contains(status);
  }

  static bool _isOverdue(Map<String, dynamic> installment, DateTime now) {
    if (!_isPending(installment)) return false;
    final due = DateTime.tryParse(jString(installment, ['dueDate']));
    if (due == null) return false;
    return due.toLocal().isBefore(DateTime(now.year, now.month, now.day));
  }

  static Map<String, dynamic> normalizeCredit(
    Map<String, dynamic> raw, {
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final level = jInt(raw, ['level', 'creditLevel'], 1).clamp(1, 6).toInt();
    final rule = ruleFor(level);
    final installments = jList(raw, ['installments'])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final pending = installments.where(_isPending).toList();
    final overdue = pending.where((item) => _isOverdue(item, date)).toList();

    final serverUsed = jDouble(raw, ['usedUsd', 'creditoUtilizadoUsd']);
    final senderoUsed = serverUsed.clamp(0, rule.senderoLimitUsd).toDouble();
    final senderoAvailable =
        (rule.senderoLimitUsd - senderoUsed).clamp(0, rule.senderoLimitUsd).toDouble();
    final alturaEligible = level >= 2 && pending.isEmpty && overdue.isEmpty;
    final next = nextRuleFor(level);

    return {
      ...raw,
      'level': level,
      'levelName': rule.name,
      'creditLimitUsd': rule.senderoLimitUsd,
      'cupoTotalUsd': rule.senderoLimitUsd,
      'usedUsd': senderoUsed,
      'availableUsd': senderoAvailable,
      'saldoDisponibleUsd': senderoAvailable,
      'downPaymentPercent': initialPercent,
      'maxInstallments': rule.maxInstallments,
      'levelRules': levelRules,
      'nextLevelAtPayments': next?.completedPaymentsRequired ?? 0,
      'senderoLine': {
        'code': 'SENDERO',
        'name': senderoName,
        'limitUsd': rule.senderoLimitUsd,
        'usedUsd': senderoUsed,
        'availableUsd': senderoAvailable,
        'initialPercent': initialPercent,
        'maxInstallments': rule.maxInstallments,
        'status': jBool(raw, ['creditSuspended']) ? 'SUSPENDED' : 'ACTIVE',
      },
      'alturaLine': {
        'code': 'ALTURA',
        'name': alturaName,
        'limitUsd': rule.alturaLimitUsd,
        'usedUsd': 0.0,
        'availableUsd': alturaEligible ? rule.alturaLimitUsd : 0.0,
        'initialPercent': initialPercent,
        'maxInstallments': rule.maxInstallments,
        'eligible': alturaEligible,
        'status': level < 2
            ? 'LOCKED_LEVEL'
            : alturaEligible
                ? 'ACTIVE'
                : 'LOCKED_PENDING',
        'lockedReason': level < 2
            ? 'Disponible desde Nivel 2 · El Ávila.'
            : alturaEligible
                ? ''
                : 'Ponte al día: Kredi Altura exige 0 cuotas pendientes.',
      },
      'pendingInstallmentsCount': pending.length,
      'overdueInstallmentsCount': overdue.length,
    };
  }
}

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../core/utils/presentation.dart';
import '../../shared/widgets/kredi_fintech.dart';

class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  late Future<Map<String, dynamic>> future;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      AppScope.of(context).api.credit().timeout(const Duration(seconds: 15));

  Future<void> reload() async {
    setState(() => future = _load());
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return KrediEmptyState(
              icon: KrediIcons.credit,
              title: 'No pudimos cargar tus líneas',
              message: 'Revisa tu conexión y vuelve a intentarlo.',
              actionLabel: 'Reintentar',
              onAction: reload,
            );
          }

          final credit = snap.data ?? const <String, dynamic>{};
          final installments = jList(credit, ['installments'])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final nextRaw = credit['nextInstallment'];
          final next = nextRaw is Map
              ? Map<String, dynamic>.from(nextRaw)
              : <String, dynamic>{};
          final sendero = credit['senderoLine'] is Map
              ? Map<String, dynamic>.from(credit['senderoLine'] as Map)
              : <String, dynamic>{};
          final altura = credit['alturaLine'] is Map
              ? Map<String, dynamic>.from(credit['alturaLine'] as Map)
              : <String, dynamic>{};
          final level = jInt(credit, ['level'], 1).clamp(1, 6).toInt();
          final levelName = KrediCreditPolicy.ruleFor(level).name;
          final senderoActive =
              jString(sendero, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE';
          final alturaActive =
              jBool(altura, ['eligible']) &&
              jString(altura, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE';

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                const SizedBox(height: 2),
                _LevelHeader(level: level, name: levelName),
                const SizedBox(height: 12),
                if (senderoActive)
                  _CreditProductCard(
                    icon: KrediIcons.sendero,
                    name: KrediCreditPolicy.senderoName,
                    subtitle: 'Tu línea principal',
                    limitUsd: jDouble(sendero, ['limitUsd']),
                    availableUsd: jDouble(sendero, ['availableUsd']),
                    maxInstallments: jInt(sendero, ['maxInstallments'], 2).clamp(1, KrediCreditPolicy.maximumInstallments).toInt(),
                  ),
                if (senderoActive && alturaActive) const SizedBox(height: 10),
                if (alturaActive)
                  _CreditProductCard(
                    icon: KrediIcons.altura,
                    name: KrediCreditPolicy.alturaName,
                    subtitle: 'Disponible porque estás al día',
                    limitUsd: jDouble(altura, ['limitUsd']),
                    availableUsd: jDouble(altura, ['availableUsd']),
                    maxInstallments: jInt(altura, ['maxInstallments'], 2).clamp(1, KrediCreditPolicy.maximumInstallments).toInt(),
                  ),
                if (!senderoActive && !alturaActive) ...[
                  const SizedBox(height: 10),
                  const KrediEmptyState(
                    icon: KrediIcons.credit,
                    title: 'Sin líneas activas',
                    message: 'Cuando tengas una línea disponible aparecerá aquí.',
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Beneficios de tus líneas',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  if (senderoActive)
                    _LineBenefitsCard(
                      name: KrediCreditPolicy.senderoName,
                      availableUsd: jDouble(sendero, ['availableUsd']),
                      maxInstallments: jInt(sendero, ['maxInstallments'], 2).clamp(1, KrediCreditPolicy.maximumInstallments).toInt(),
                    ),
                  if (senderoActive && alturaActive) const SizedBox(height: 8),
                  if (alturaActive)
                    _LineBenefitsCard(
                      name: KrediCreditPolicy.alturaName,
                      availableUsd: jDouble(altura, ['availableUsd']),
                      maxInstallments: jInt(altura, ['maxInstallments'], 2).clamp(1, KrediCreditPolicy.maximumInstallments).toInt(),
                    ),
                  const SizedBox(height: 12),
                ],
                _StatusCard(credit: credit, next: next),
                if (installments.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Cuotas',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  for (final installment in installments.take(12)) ...[
                    _InstallmentCard(item: installment),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
      );


}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.level, required this.name});
  final int level;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KrediColors.softOrange,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KrediColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: KrediColors.orange, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$level', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nivel $level · $name', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('0% inicial', style: TextStyle(fontSize: 12, color: KrediColors.secondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CreditProductCard extends StatelessWidget {
  const _CreditProductCard({
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.limitUsd,
    required this.availableUsd,
    required this.maxInstallments,
  });

  final IconData icon;
  final String name;
  final String subtitle;
  final double limitUsd;
  final double availableUsd;
  final int maxInstallments;

  @override
  Widget build(BuildContext context) {
    final availableProgress = limitUsd <= 0
        ? 0.0
        : (availableUsd / limitUsd).clamp(0.0, 1.0).toDouble();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E1D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0B0B0C),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Container(
              width: 138,
              height: 138,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x36FD9C24), Color(0x00FD9C24)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: KrediColors.softOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD092)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: KrediColors.orangeDeep, size: 22),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: KrediColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: KrediColors.softGreen,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Activa',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: KrediColors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'US\$ ${availableUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.45,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Disponible para comprar',
                  style: TextStyle(fontSize: 11.5, color: KrediColors.secondary),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: availableProgress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: const Color(0xFFF2E7D7),
                  color: KrediColors.orange,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _CreditMeta(label: 'Límite', value: 'US\$ ${limitUsd.toStringAsFixed(0)}')),
                    Container(width: 1, height: 28, color: KrediColors.border),
                    Expanded(child: _CreditMeta(label: 'Cuotas', value: '$maxInstallments')),
                    Container(width: 1, height: 28, color: KrediColors.border),
                    const Expanded(child: _CreditMeta(label: 'Inicial', value: '0%')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditMeta extends StatelessWidget {
  const _CreditMeta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: KrediColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _LineBenefitsCard extends StatelessWidget {
  const _LineBenefitsCard({required this.name, required this.availableUsd, required this.maxInstallments});
  final String name;
  final double availableUsd;
  final int maxInstallments;

  @override
  Widget build(BuildContext context) => KrediOutlineCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _BenefitPill(icon: KrediIcons.success, label: '0% inicial'),
                _BenefitPill(icon: KrediIcons.receipt, label: 'Hasta $maxInstallments cuotas'),
                _BenefitPill(icon: KrediIcons.credit, label: 'Disponible US\$ ${availableUsd.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      );
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: KrediColors.softOrange, borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: KrediColors.orangeDeep),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.credit, required this.next});
  final Map<String, dynamic> credit;
  final Map<String, dynamic> next;

  @override
  Widget build(BuildContext context) {
    final activeLoans = jInt(credit, ['activeLoans']);
    final completed = jInt(credit, ['completedPayments']);
    final late = jInt(credit, ['latePaymentCount']);
    final pending = jInt(credit, ['pendingInstallmentsCount']);
    return KrediOutlineCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(KrediIcons.credit, size: 20),
              SizedBox(width: 8),
              Text('Estado de tus líneas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text('$activeLoans plan${activeLoans == 1 ? '' : 'es'} activo${activeLoans == 1 ? '' : 's'}'),
          const SizedBox(height: 4),
          Text('$completed pago${completed == 1 ? '' : 's'} completado${completed == 1 ? '' : 's'}'),
          const SizedBox(height: 4),
          Text('$pending cuota${pending == 1 ? '' : 's'} pendiente${pending == 1 ? '' : 's'}'),
          if (late > 0) ...[
            const SizedBox(height: 4),
            Text('$late atraso${late == 1 ? '' : 's'} registrado${late == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (next.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Próxima cuota', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text('US\$ ${jDouble(next, ['amountUsd']).toStringAsFixed(2)} · ${dateLabel(next['dueDate'])}'),
          ],
        ],
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = jString(item, ['status'], 'PENDING');
    return KrediOutlineCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Icon(KrediIcons.receipt, color: KrediColors.coral),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cuota ${jInt(item, ['installmentNumber'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('Vence ${dateLabel(item['dueDate'])}', style: const TextStyle(fontSize: 12, color: KrediColors.secondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('US\$ ${jDouble(item, ['amountUsd']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(statusLabel(status), style: const TextStyle(fontSize: 11, color: KrediColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 86,
        child: KrediOutlineCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: KrediColors.secondary)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

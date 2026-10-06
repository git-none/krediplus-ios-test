import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/utils/json_read.dart';
import '../../shared/widgets/kredi_fintech.dart';

class _Movement {
  _Movement(
    this.kind,
    this.title,
    this.subtitle,
    this.amount,
    this.status,
    this.date,
  );
  final String kind, title, subtitle, amount, status, date;
}

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  List<_Movement> all = [];
  String filter = 'Todos';
  bool busy = true;
  String? error;
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final api = AppScope.of(context).api;
      final r = await Future.wait([
        api.purchases(),
        api.credit(),
        api.creditTransactions(),
      ]);
      final purchases = List<Map<String, dynamic>>.from(r[0] as List);
      final credit = Map<String, dynamic>.from(r[1] as Map);
      final txs = List<Map<String, dynamic>>.from(r[2] as List);
      final m = <_Movement>[];
      for (final p in purchases) {
        final pm = jString(p, ['paymentMethod']);
        m.add(
          _Movement(
            'Compras',
            jString(p, ['invoiceNumber'], 'Compra #${jInt(p, ['id'])}'),
            '${jInt(p, ['itemCount'])} artículos · ${pm.isEmpty ? 'Método no indicado' : _status(pm)}',
            _usd(jDouble(p, ['total'])),
            _status(jString(p, ['status'])),
            _dateMillis(jInt(p, ['createdAtMillis'])),
          ),
        );
        if (pm.toUpperCase() == 'CREDIMPULSO') {
          m.add(
            _Movement(
              'Línea',
              'Plan de ${jString(p, ['invoiceNumber'], 'compra #${jInt(p, ['id'])}')}',
              '${jInt(p, ['itemCount'])} artículos comprados con tus líneas Kredi+',
              _usd(jDouble(p, ['total'])),
              _status(jString(p, ['status'])),
              _dateMillis(jInt(p, ['createdAtMillis'])),
            ),
          );
        }
      }
      for (final raw in jList(credit, ['installments']).whereType<Map>()) {
        final i = Map<String, dynamic>.from(raw);
        final s = jString(i, ['status']).toUpperCase();
        if (![
          'PAID',
          'PAGADO',
          'COMPLETED',
          'COMPLETADO',
          'CANCELLED',
          'CANCELADO',
        ].contains(s)) {
          final pd = jMap(i, ['paymentDestination']);
          final b = pd?['business'] is Map
              ? Map<String, dynamic>.from(pd!['business'] as Map)
              : null;
          m.add(
            _Movement(
              'Pagos',
              'Cuota ${jInt(i, ['installmentNumber'])} por pagar',
              'Vence ${jString(i, ['dueDate'])}${b != null ? ' · Pagar a ${jString(b, ['commercialName'])}' : ''}',
              _usd(jDouble(i, ['amountUsd'])),
              _status(jString(i, ['status'])),
              jString(i, ['dueDate']),
            ),
          );
        }
      }
      final used = jDouble(credit, ['usedUsd']);
      if (used > 0) {
        m.add(
          _Movement(
            'Línea',
            'Línea utilizada',
            'En compras ${_usd(used)} · Disponible ${_usd(jDouble(credit, ['availableUsd']))} de ${_usd(jDouble(credit, ['creditLimitUsd']))}',
            _usd(used),
            _status(jString(credit, ['status'])),
            'Estado actual',
          ),
        );
      }
      for (final t in txs) {
        final type = jString(t, ['transactionType']).toUpperCase();
        if (!type.contains('PURCHASE') &&
            !type.contains('COMPRA') &&
            !type.contains('PAYMENT') &&
            !type.contains('PAGO') &&
            !type.contains('INSTALLMENT')) {
          m.add(
            _Movement(
              'Línea',
              jString(t, ['description'], _status(type)),
              jString(t, ['invoiceNumber'], 'Actividad de tus líneas Kredi+'),
              _usd(jDouble(t, ['amountUsd'])),
              _status(type),
              jString(t, ['createdAt']),
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          all = m;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    final visible = filter == 'Todos'
        ? all
        : all.where((e) => e.kind == filter).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const KrediScreenTitle(
            'Actividad',
            subtitle:
                'Compras, cuotas y pagos reportados organizados en un solo historial.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = ['Todos', 'Compras', 'Pagos', 'Línea'][index];
                return ChoiceChip(
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                  selectedColor: KrediColors.softOrange,
                  labelStyle: TextStyle(
                    color: filter == f ? KrediColors.orangeDeep : KrediColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  side: const BorderSide(color: KrediColors.border),
                  label: Text(
                    '$f (${f == 'Todos' ? all.length : all.where((e) => e.kind == f).length})',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (error != null)
            KrediEmptyState(
              icon: KrediIcons.offline,
              title: 'No pudimos cargar tu actividad',
              message: error,
            )
          else if (visible.isEmpty)
            KrediEmptyState(
              icon: KrediIcons.movements,
              title: 'Sin actividad',
              message: 'No hay registros para $filter.',
            )
          else
            for (final movement in visible) ...[
              KrediOutlineCard(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _color(movement.kind).withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _icon(movement.kind),
                        color: _color(movement.kind),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movement.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            movement.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: KrediColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${movement.status} · ${movement.date}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: KrediColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 92),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          movement.amount,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  IconData _icon(String k) => k == 'Compras'
      ? KrediIcons.shop
      : k == 'Pagos'
      ? KrediIcons.payments
      : KrediIcons.credit;
  Color _color(String k) => k == 'Compras'
      ? KrediColors.orange
      : k == 'Pagos'
      ? KrediColors.green
      : KrediColors.violet;
}

String _usd(double v) => NumberFormat.currency(
  locale: 'en_US',
  symbol: 'US\$ ',
  decimalDigits: 2,
).format(v);
String _status(String s) => s
    .replaceAll('_', ' ')
    .toLowerCase()
    .split(' ')
    .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
    .join(' ');
String _dateMillis(int ms) => ms <= 0
    ? ''
    : DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));

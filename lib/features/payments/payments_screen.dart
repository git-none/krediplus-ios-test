import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/input/kredi_input_formatters.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/utils/json_read.dart';
import '../../core/utils/presentation.dart';
import '../../core/utils/payment_validation.dart';
import '../../shared/widgets/bank_selector.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../../shared/widgets/kredi_media.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _BeneficiaryPayments();
}

class _BeneficiaryPayments extends StatefulWidget {
  const _BeneficiaryPayments();

  @override
  State<_BeneficiaryPayments> createState() => _BeneficiaryPaymentsState();
}

class _PaymentsLoad {
  const _PaymentsLoad({
    required this.credit,
    required this.purchases,
    required this.reports,
    required this.errors,
  });

  final Map<String, dynamic> credit;
  final List<Map<String, dynamic>> purchases;
  final List<Map<String, dynamic>> reports;
  final List<String> errors;
}

class _BeneficiaryPaymentsState extends State<_BeneficiaryPayments> {
  late Future<_PaymentsLoad> future;
  int tab = 0;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    future = _load();
  }

  Future<_PaymentsLoad> _load() async {
    final api = AppScope.of(context).api;
    final errors = <String>[];

    Future<T> safe<T>(
      String label,
      Future<T> Function() action,
      T fallback,
    ) async {
      try {
        return await action().timeout(const Duration(seconds: 15));
      } catch (_) {
        errors.add(label);
        return fallback;
      }
    }

    final rows = await Future.wait<dynamic>([
      safe('línea y cuotas', api.credit, <String, dynamic>{}),
      safe('compras', api.purchases, <Map<String, dynamic>>[]),
      safe('comprobantes', api.paymentReports, <Map<String, dynamic>>[]),
    ]);
    return _PaymentsLoad(
      credit: Map<String, dynamic>.from(rows[0] as Map),
      purchases: List<Map<String, dynamic>>.from(rows[1] as List),
      reports: List<Map<String, dynamic>>.from(rows[2] as List),
      errors: errors,
    );
  }

  Future<void> reload() async {
    setState(() => future = _load());
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PaymentsLoad>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final result = snap.data ?? const _PaymentsLoad(
          credit: <String, dynamic>{},
          purchases: <Map<String, dynamic>>[],
          reports: <Map<String, dynamic>>[],
          errors: ['pagos'],
        );
        final credit = result.credit;
        final purchases = result.purchases;
        final reports = result.reports;
        final installments = jList(credit, ['installments'])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final due = installments
            .where(
              (e) => !const {
                'PAID',
                'PAGADO',
                'COMPLETED',
                'COMPLETADO',
                'CANCELLED',
                'CANCELED',
              }.contains(jString(e, ['status']).toUpperCase()),
            )
            .toList();
        final pendingPurchases = purchases.where(purchaseNeedsPayment).toList();
        final pendingCount = due.length + pendingPurchases.length;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const Text(
                'Tus pagos',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Material(
                  color: KrediColors.softOrange,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: reload,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(KrediIcons.refresh, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No cargó: ${result.errors.join(', ')}. Toca para reintentar.',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _PaymentTab(
                      label: 'Pendientes',
                      count: pendingCount,
                      selected: tab == 0,
                      onTap: () => setState(() => tab = 0),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _PaymentTab(
                      label: 'Comprobantes',
                      count: reports.length,
                      selected: tab == 1,
                      onTap: () => setState(() => tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (tab == 0) ...[
                if (pendingCount == 0)
                  const KrediEmptyState(
                    icon: KrediIcons.calendar,
                    title: 'No tienes pagos pendientes',
                    message: 'Tus cuotas y pagos aparecerán aquí cuando corresponda.',
                  )
                else ...[
                  if (due.isNotEmpty) ...[
                    const KrediSectionRow(title: 'Cuotas'),
                    const SizedBox(height: 10),
                    for (final item in due) ...[
                      _PendingPaymentCard(
                        icon: KrediIcons.calendar,
                        title: jInt(item, ['installmentNumber']) > 0
                            ? 'Cuota ${jInt(item, ['installmentNumber'])}'
                            : 'Cuota pendiente',
                        amount: _displayAmount(item['amountUsd'], moneyUsd),
                        subtitle: item['dueDate'] == null
                            ? 'Fecha de vencimiento no disponible'
                            : 'Vence el ${dateLabel(item['dueDate'])}',
                        onPay: () => _openInstallment(item),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (pendingPurchases.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const KrediSectionRow(title: 'Compras'),
                    const SizedBox(height: 10),
                    for (final item in pendingPurchases) ...[
                      _PendingPaymentCard(
                        icon: KrediIcons.shop,
                        title: jString(
                          item,
                          ['invoiceNumber'],
                          'Compra #${jInt(item, ['id'])}',
                        ),
                        amount: _displayAmount(item['total'], moneyBs),
                        subtitle: statusLabel(jString(item, ['status'], 'PENDING')),
                        onPay: () => _openPurchase(item),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ] else ...[
                if (reports.isEmpty)
                  const KrediEmptyState(
                    icon: KrediIcons.receipt,
                    title: 'Aún no tienes pagos reportados',
                    message: 'Tus comprobantes enviados aparecerán aquí.',
                  )
                else
                  for (final report in reports) ...[
                    KrediOutlineCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            jString(report, ['referenceNumber']).isEmpty
                                ? 'Comprobante enviado'
                                : 'Referencia ${jString(report, ['referenceNumber'])}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(statusLabel(jString(report, ['status'])), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(dateLabel(report['createdAt']), style: const TextStyle(color: KrediColors.secondary)),
                          if (jString(report, ['proofUrl']).trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            KrediProofButton(
                              url: jString(report, ['proofUrl']),
                              label: 'Abrir comprobante',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ],
          ),
        );
      },
    );
  }

  void _openInstallment(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentReportForm(
          targetType: 'CREDIT_INSTALLMENT',
          installmentId: jInt(item, ['id']),
          amountBs: jDouble(item, ['originalAmountBs']),
          destination: item['paymentDestination'] is Map
              ? Map<String, dynamic>.from(item['paymentDestination'] as Map)
              : null,
          onSuccess: reload,
        ),
      ),
    );
  }

  void _openPurchase(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentReportForm(
          targetType: 'ORDER',
          orderId: jInt(item, ['id']),
          amountBs: jDouble(item, ['total']),
          destination: item['paymentDestination'] is Map
              ? Map<String, dynamic>.from(item['paymentDestination'] as Map)
              : null,
          onSuccess: reload,
        ),
      ),
    );
  }
}


class _PaymentTab extends StatelessWidget {
  const _PaymentTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: KrediMotion.standard,
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? KrediColors.orangeDeep : KrediColors.border,
                width: selected ? 3 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? KrediColors.orangeDeep : KrediColors.secondary,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? KrediColors.softOrange : const Color(0xFFF3F4F5),
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? KrediColors.orangeDeep : KrediColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.onPay,
  });

  final IconData icon;
  final String title;
  final String amount;
  final String subtitle;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KrediColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Center(
              child: Icon(icon, color: KrediColors.coral, size: 24),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: KrediColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 7),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(92, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  backgroundColor: KrediColors.orange,
                  foregroundColor: KrediColors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: onPay,
                child: const Text('Pagar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class PaymentReportForm extends StatefulWidget {
  const PaymentReportForm({
    super.key,
    required this.targetType,
    this.orderId,
    this.installmentId,
    required this.amountBs,
    this.destination,
    this.onSuccess,
  });
  final String targetType;
  final int? orderId;
  final int? installmentId;
  final double amountBs;
  final Map<String, dynamic>? destination;
  final VoidCallback? onSuccess;

  @override
  State<PaymentReportForm> createState() => _PaymentReportFormState();
}

class _PaymentReportFormState extends State<PaymentReportForm> {
  String method = 'MOBILE_PAYMENT';
  final bank = TextEditingController();
  final phone = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();
  late final TextEditingController paidAmount;
  File? proof;
  bool different = false;
  bool busy = false;

  List<String> get availableMethods =>
      availablePaymentMethods(widget.destination ?? const {});

  @override
  void initState() {
    super.initState();
    paidAmount = TextEditingController(
      text: widget.amountBs.toStringAsFixed(2).replaceAll('.', ','),
    );
    if (availableMethods.isNotEmpty) method = availableMethods.first;
  }

  @override
  void dispose() {
    bank.dispose();
    phone.dispose();
    reference.dispose();
    notes.dispose();
    paidAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar pago')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const KrediScreenTitle(
            'Reporta tu pago',
            subtitle:
                'Envía los datos y el comprobante de tu pago.',
          ),
          const SizedBox(height: 16),
          const KrediSectionRow(title: '1. Datos para pagar'),
          const SizedBox(height: 12),
          _destinationCard(),
          const SizedBox(height: 14),
          if (availableMethods.isEmpty)
            const KrediEmpty(
              'Destino de pago no disponible',
              'El comercio aún no tiene un destino de pago.',
              icon: KrediIcons.bank,
            )
          else
            DropdownButtonFormField<String>(
              initialValue: method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Forma de pago'),
              items: [
                for (final value in availableMethods)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'MOBILE_PAYMENT'
                          ? 'Pago móvil'
                          : 'Transferencia bancaria',
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => method = value);
                    },
            ),
          const SizedBox(height: 20),
          const KrediSectionRow(title: '2. Tu comprobante'),
          const SizedBox(height: 12),
          TextField(
            controller: paidAmount,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [KrediDecimalInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Monto realmente pagado en Bs',
              helperText:
                  'Esperado: ${moneyBs(widget.amountBs)}',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 14),
          BankSelector(controller: bank, enabled: !busy),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(
              labelText: 'Teléfono de origen',
              hintText: '04141234567',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: reference,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Referencia'),
          ),
          SwitchListTile(
            value: different,
            onChanged: (value) => setState(() => different = value),
            title: const Text('Pagué desde otro teléfono'),
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickProof,
            icon: const Icon(KrediIcons.image),
            label: Text(
              proof == null
                  ? 'Adjuntar comprobante'
                  : 'Comprobante seleccionado',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy || availableMethods.isEmpty ? null : _submit,
            icon: const Icon(KrediIcons.send),
            label: const Text('Enviar reporte de pago'),
          ),
        ],
      ),
    );
  }

  Widget _destinationCard() {
    final data = widget.destination ?? const <String, dynamic>{};
    final fields = paymentDestinationFields(data, method, widget.amountBs);
    return KrediOutlineCard(
      child: Column(
        children: [
          for (final entry in fields.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: SelectableText(entry.value),
              trailing: IconButton(
                onPressed: () => _copy(entry.value),
                icon: const Icon(KrediIcons.copy),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _copy(
              fields.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            ),
            icon: const Icon(KrediIcons.copyAll),
            label: const Text('Copiar todos los datos'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value.trim()));
    if (mounted) showKrediMessage(context, 'Copiado correctamente.');
  }

  Future<void> _pickProof() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (image != null && mounted) setState(() => proof = File(image.path));
  }

  Future<void> _submit() async {
    if (busy) return;
    final amount = parseReportedAmountBs(paidAmount.text);
    if (proof == null ||
        reference.text.trim().isEmpty ||
        bank.text.trim().isEmpty ||
        !RegExp(r'^0[0-9]{10}$').hasMatch(phone.text.trim()) ||
        amount == null ||
        amount <= 0 ||
        !availableMethods.contains(method)) {
      showKrediMessage(
        context,
        'Completa banco, teléfono, referencia, monto y comprobante.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.uploadPaymentReport(
        targetType: widget.targetType,
        orderId: widget.orderId,
        installmentId: widget.installmentId,
        method: method,
        originBankCode: bank.text.trim(),
        originPhone: phone.text.trim(),
        referenceNumber: reference.text.trim(),
        amountBs: amount,
        paidFromDifferentPhone: different,
        notes: notes.text.trim(),
        proof: proof!,
      );
      widget.onSuccess?.call();
      if (mounted) {
        showKrediMessage(context, 'Pago reportado correctamente.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showKrediMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

String _displayAmount(Object? value, String Function(num) format) {
  final amount = value is num ? value : num.tryParse('${value ?? ''}');
  return amount == null || !amount.isFinite
      ? 'Monto no disponible'
      : format(amount);
}

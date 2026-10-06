import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/credit/kredi_credit_policy.dart';
import '../../core/utils/json_read.dart';
import '../../core/utils/payment_validation.dart';
import '../../core/utils/presentation.dart';
import '../../shared/widgets/bank_selector.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../../core/icons/kredi_icons.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String method = 'MOBILE_PAYMENT';
  final reference = TextEditingController();
  final originBank = TextEditingController();
  final originPhone = TextEditingController();
  bool differentPhone = false;
  File? proof;
  bool busy = false;
  String creditLine = 'SENDERO';
  Future<Map<String, dynamic>>? _creditFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _creditFuture ??= AppScope.of(context)
        .api
        .credit()
        .timeout(const Duration(seconds: 15));
  }
  @override
  void dispose() {
    reference.dispose();
    originBank.dispose();
    originPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context).app;
    final forCombos = app.comboCart.isNotEmpty;
    final contextData = app.paymentContext(forCombos: forCombos);
    final methods = [
      ...availablePaymentMethods(contextData ?? const {}),
      'CREDIMPULSO',
    ];
    if (!methods.contains(method)) method = methods.first;
    final totalUsd = app.subtotalUsd;
    final totalBs = app.subtotalBs;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar compra')),
      body: AnimatedBuilder(
        animation: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const KrediSectionTitle('Revisa tu compra'),
            const SizedBox(height: 12),
            ..._cartLines(app),
            const Divider(height: 28),
            _moneyRow('Subtotal', _usd(totalUsd)),
            _moneyRow(
              'Tasa BCV',
              app.bcvRate > 0
                  ? '${app.bcvRate.toStringAsFixed(2)} Bs/US\$'
                  : 'No disponible',
            ),
            _moneyRow('TOTAL', _bs(totalBs), strong: true),
            const SizedBox(height: 18),
            if (contextData == null)
              const KrediEmpty(
                'Pago no disponible',
                'Este comercio aún no tiene receptor de pago configurado.',
                icon: KrediIcons.storefront,
              )
            else ...[
              if (method != 'CREDIMPULSO') _businessCard(contextData, totalBs),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(methods.join(',')),
                initialValue: method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Forma de pago'),
                items: [
                  if (methods.contains('MOBILE_PAYMENT'))
                    DropdownMenuItem(
                      value: 'MOBILE_PAYMENT',
                      child: Text('Pago móvil'),
                    ),
                  if (methods.contains('BANK_TRANSFER'))
                    DropdownMenuItem(
                      value: 'BANK_TRANSFER',
                      child: Text('Transferencia bancaria'),
                    ),
                  const DropdownMenuItem(
                    value: 'CREDIMPULSO',
                    child: Text('Comprar con Kredi+'),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => method = value);
                      },
              ),
              const SizedBox(height: 14),
              if (method == 'CREDIMPULSO') ...[
                _creditLineSelector(totalUsd),
                const SizedBox(height: 14),
              ],
              if (method != 'CREDIMPULSO') ...[
                TextField(
                  controller: reference,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Referencia'),
                ),
                const SizedBox(height: 10),
                BankSelector(controller: originBank, enabled: !busy),
                const SizedBox(height: 10),
                TextField(
                  controller: originPhone,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Celular de origen',
                    hintText: '04141234567',
                  ),
                ),
                SwitchListTile(
                  value: differentPhone,
                  onChanged: (v) => setState(() => differentPhone = v),
                  title: const Text('Pagué desde otro número'),
                  contentPadding: EdgeInsets.zero,
                ),
                OutlinedButton.icon(
                  onPressed: _pickProof,
                  icon: const Icon(KrediIcons.image),
                  label: Text(
                    proof == null
                        ? 'Adjuntar comprobante'
                        : 'Comprobante seleccionado',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : _pay,
                icon: const Icon(KrediIcons.lock),
                label: Text(
                  busy
                      ? 'Procesando…'
                      : method == 'CREDIMPULSO'
                      ? 'Confirmar compra'
                      : 'Enviar compra y comprobante',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _creditLineSelector(double totalUsd) {
    final future = _creditFuture;
    if (future == null) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Consultando tus líneas…')),
                ],
              ),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No pudimos consultar tus líneas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text('Intenta de nuevo antes de confirmar la compra.'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _creditFuture = AppScope.of(context)
                          .api
                          .credit()
                          .timeout(const Duration(seconds: 15));
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final credit = snap.data!;
        final sendero = jMap(credit, ['senderoLine']) ?? const <String, dynamic>{};
        final altura = jMap(credit, ['alturaLine']) ?? const <String, dynamic>{};
        final senderoActive =
            jString(sendero, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE';
        final alturaEligible =
            jBool(altura, ['eligible']) &&
            jString(altura, ['status'], 'ACTIVE').toUpperCase() == 'ACTIVE';
        final selectedActive =
            (creditLine == 'SENDERO' && senderoActive) ||
            (creditLine == 'ALTURA' && alturaEligible);
        if (!selectedActive && (senderoActive || alturaEligible)) {
          final fallback = senderoActive ? 'SENDERO' : 'ALTURA';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && creditLine != fallback) setState(() => creditLine = fallback);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elige tu línea',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (!senderoActive && !alturaEligible)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No tienes líneas activas disponibles para esta compra.',
                  style: TextStyle(color: KrediColors.navySoft),
                ),
              ),
            if (senderoActive)
              _creditChoice(
                code: 'SENDERO',
                name: KrediCreditPolicy.senderoName,
                availableUsd: jDouble(sendero, ['availableUsd']),
                subtitle: _creditSummary(
                  totalUsd,
                  jInt(sendero, ['maxInstallments'], 2),
                ),
                enabled: true,
              ),
            if (senderoActive && alturaEligible) const SizedBox(height: 8),
            if (alturaEligible)
              _creditChoice(
                code: 'ALTURA',
                name: KrediCreditPolicy.alturaName,
                availableUsd: jDouble(altura, ['availableUsd']),
                subtitle: _creditSummary(
                  totalUsd,
                  jInt(altura, ['maxInstallments'], 2),
                ),
                enabled: true,
              ),
          ],
        );
      },
    );
  }

  String _creditSummary(double totalUsd, int rawInstallments) {
    final installments = rawInstallments.clamp(1, KrediCreditPolicy.maximumInstallments).toInt();
    final perInstallment = totalUsd / installments;
    return '$installments cuotas · ${_usd(perInstallment)} c/u · 0% inicial';
  }

  Widget _creditChoice({
    required String code,
    required String name,
    required double availableUsd,
    required String subtitle,
    required bool enabled,
  }) {
    final selected = creditLine == code;
    final canSelect = enabled && !busy;
    return KrediPressable(
      onTap: canSelect ? () => setState(() => creditLine = code) : () {},
      enabled: canSelect,
      pressedScale: .985,
      child: AnimatedContainer(
        duration: KrediMotion.standard,
        curve: KrediMotion.enter,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : KrediColors.softCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected && enabled
                ? KrediColors.orange
                : KrediColors.border,
            width: selected && enabled ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              enabled ? KrediIcons.credit : Icons.lock_outline_rounded,
              color: enabled ? KrediColors.orange : KrediColors.navySoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled
                        ? 'Disponible ${_usd(availableUsd)} · $subtitle'
                        : subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: KrediColors.navySoft,
                    ),
                  ),
                ],
              ),
            ),
            if (selected && enabled)
              const Icon(Icons.check_circle_rounded, color: KrediColors.orange),
          ],
        ),
      ),
    );
  }

  List<Widget> _cartLines(dynamic app) {
    final out = <Widget>[];
    for (final e in app.productCart.entries) {
      final p = app.productById(e.key);
      if (p != null) {
        out.add(_line(
          jString(p, ['name']),
          e.value,
          app.productPriceUsd(p),
          AppConfig.publicUrl(jString(p, ['imageUrl', 'imagePath', 'image'])),
        ));
      }
    }
    for (final e in app.comboCart.entries) {
      final c = app.comboById(e.key);
      if (c != null) {
        out.add(_line(
          jString(c, ['name']),
          e.value,
          app.comboPriceUsd(c),
          AppConfig.publicUrl(jString(c, ['coverUrl', 'imageUrl', 'imagePath', 'image'])),
        ));
      }
    }
    return out;
  }

  Widget _line(String name, int qty, double price, String imageUrl) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF7F7F8),
                      child: Center(
                        child: Icon(
                          KrediIcons.image,
                          color: KrediColors.secondary,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF7F7F8),
                        child: Center(
                          child: Icon(
                            KrediIcons.image,
                            color: KrediColors.secondary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$qty × ${_usd(price)}',
                  style: const TextStyle(color: KrediColors.secondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subtotal: ${_usd(price * qty)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _moneyRow(String l, String v, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: strong ? 19 : 14,
            color: strong ? KrediColors.green : null,
          ),
        ),
      ],
    ),
  );
  Widget _businessCard(Map<String, dynamic> ctx, double totalBs) {
    final b = ctx['business'] is Map
        ? Map<String, dynamic>.from(ctx['business'] as Map)
        : ctx;
    final lines = paymentDestinationFields(
      {...b, ...ctx, 'business': b},
      method,
      totalBs,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos para pagar',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final e in lines.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                subtitle: SelectableText(e.value),
                trailing: IconButton(
                  onPressed: () => _copy(e.value),
                  icon: const Icon(KrediIcons.copy),
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _copy(
                lines.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              ),
              icon: const Icon(KrediIcons.copyAll),
              label: const Text('Copiar todos los datos, incluido el monto'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value.trim()));
    if (mounted) showKrediMessage(context, 'Copiado correctamente.');
  }

  Future<void> _pickProof() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (x != null && mounted) setState(() => proof = File(x.path));
  }

  Future<void> _pay() async {
    if (busy) return;
    final scope = AppScope.of(context);
    final app = scope.app;
    final destination = app.paymentContext(forCombos: app.comboCart.isNotEmpty);
    if (destination == null ||
        (method != 'CREDIMPULSO' &&
            !availablePaymentMethods(destination).contains(method))) {
      showKrediMessage(
        context,
        'La forma de pago seleccionada no tiene un destino disponible. Actualiza el catálogo.',
      );
      return;
    }
    if (app.cartCount == 0 || app.bcvRate <= 0) {
      showKrediMessage(
        context,
        'La compra necesita productos y una tasa BCV válida. Actualiza el catálogo.',
      );
      return;
    }
    if (method != 'CREDIMPULSO' &&
        (originBank.text.trim().isEmpty ||
            reference.text.trim().isEmpty ||
            !RegExp(r'^0[0-9]{10}$').hasMatch(originPhone.text.trim()))) {
      showKrediMessage(
        context,
        'Selecciona el banco, indica la referencia y un teléfono de 11 dígitos.',
      );
      return;
    }
    if (method != 'CREDIMPULSO' && proof == null) {
      showKrediMessage(context, 'Adjunta el comprobante de pago.');
      return;
    }
    if (method == 'CREDIMPULSO') {
      try {
        final credit = await scope.api
            .credit()
            .timeout(const Duration(seconds: 15));
        final line = creditLine == 'ALTURA'
            ? (jMap(credit, ['alturaLine']) ?? const <String, dynamic>{})
            : (jMap(credit, ['senderoLine']) ?? const <String, dynamic>{});
        if (creditLine == 'ALTURA' && !jBool(line, ['eligible'])) {
          showKrediMessage(
            context,
            jString(
              line,
              ['lockedReason'],
              'Kredi Altura solo está disponible con 0 cuotas pendientes.',
            ),
          );
          return;
        }
        final available = jDouble(line, ['availableUsd']);
        if (app.subtotalUsd > available + 0.0001) {
          showKrediMessage(
            context,
            'Tu ${creditLine == 'ALTURA' ? KrediCreditPolicy.alturaName : KrediCreditPolicy.senderoName} disponible es ${_usd(available)}.',
          );
          return;
        }
      } catch (_) {
        showKrediMessage(
          context,
          'No pudimos validar tus líneas. Intenta nuevamente.',
        );
        return;
      }
    }
    setState(() => busy = true);
    try {
      final items = [
        for (final e in app.productCart.entries)
          {'productId': e.key, 'quantity': e.value},
      ];
      final combos = [
        for (final e in app.comboCart.entries)
          {'comboId': e.key, 'quantity': e.value},
      ];
      if (method == 'CREDIMPULSO') {
        await scope.api.createPurchase(
          fairId: app.effectiveFairId,
          items: items,
          comboItems: combos,
          paymentMethod: 'CREDIMPULSO',
          creditLine: creditLine,
        );
      } else {
        await scope.api.createPurchaseWithProof(
          fairId: app.effectiveFairId,
          productItems: Map<int, int>.from(app.productCart),
          comboItems: Map<int, int>.from(app.comboCart),
          paymentMethod: method,
          paymentReference: reference.text.trim(),
          originBankCode: originBank.text.trim(),
          originPhone: originPhone.text.trim(),
          paidFromDifferentPhone: differentPhone,
          proof: proof!,
        );
      }
      app.clearCart();
      if (mounted) {
        showKrediMessage(context, 'Compra registrada correctamente.');
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) showKrediMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

String _usd(double v) => NumberFormat.currency(
  locale: 'en_US',
  symbol: 'US\$ ',
  decimalDigits: 2,
).format(v);
String _bs(double v) => 'Bs ${NumberFormat('#,##0.00', 'es_VE').format(v)}';

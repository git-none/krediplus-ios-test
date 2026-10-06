import 'package:intl/intl.dart';

/// Etiquetas y formatos del contrato API. Los importes heredados `total` y
/// `unitPrice` son bolívares; solo campos terminados en Usd son dólares.
String statusLabel(String? raw) =>
    const <String, String>{
      'PENDING': 'Pendiente',
      'QUOTED': 'Pendiente de confirmación',
      'PENDING_PAYMENT': 'Pendiente de pago',
      'UNPAID': 'Pendiente de pago',
      'PAID': 'Pagado',
      'COMPLETED': 'Completado',
      'CANCELLED': 'Cancelado',
      'CANCELED': 'Cancelado',
      'REJECTED': 'Rechazado',
      'EXPIRED': 'Vencido',
      'OVERDUE': 'Vencido',
      'CURRENT': 'Vigente',
      'ACTIVE': 'Activo',
      'INACTIVE': 'Inactivo',
      'APPROVED': 'Aprobado',
      'REPORTED': 'Reportado',
      'VERIFIED': 'Verificado',
      'UNDER_REVIEW': 'En revisión',
      'PREPARING': 'En preparación',
      'READY': 'Listo para retirar',
      'DELIVERED': 'Entregado',
      'RETURNED': 'Devuelto',
      'STOCK_SHORTAGE': 'Faltante de inventario',
      'AWAITING_MERCHANT': 'Esperando cotización del comercio',
      'AWAITING_CUSTOMER': 'Esperando tu confirmación',
      'AWAITING_CONFIRMATION': 'Esperando tu confirmación',
      'AWAITING_INITIAL': 'Esperando recepción de la inicial',
      'MOBILE_PAYMENT': 'Pago móvil',
      'BANK_TRANSFER': 'Transferencia bancaria',
      'CREDIMPULSO': 'Línea Kredi+',
      'QR': 'Compra QR',
      'PRODUCT': 'Producto',
      'COMBO': 'Combo',
      'OFFER': 'Oferta',
      'JOURNEY': 'Jornada',
      'SUSPENDED': 'Suspendido',
      'MANUAL_REVIEW': 'Revisión manual',
      'FAILED': 'Fallido',
      'CASH': 'Efectivo',
      'CREDIT': 'Crédito',
      'CREDIT_LINE': 'Línea Kredi+',
      'CARD': 'Tarjeta',
    }[(raw ?? '').toUpperCase()] ??
    'Sin información';

String moneyBs(num value) =>
    'Bs. ${NumberFormat('#,##0.00', 'es_VE').format(value)}';
String moneyUsd(num value) =>
    'US\$ ${NumberFormat('#,##0.00', 'es_VE').format(value)}';
String dateLabel(Object? value) {
  final date = value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : DateTime.tryParse('$value');
  return date == null
      ? 'Fecha no disponible'
      : DateFormat('dd/MM/yyyy', 'es_VE').format(date.toLocal());
}

enum PurchaseGroup { active, completed, closed }

PurchaseGroup purchaseGroup(Map<String, dynamic> row) {
  final status = (row['status'] ?? '').toString().toUpperCase();
  if (const {
    'CANCELLED',
    'CANCELED',
    'REJECTED',
    'EXPIRED',
    'RETURNED',
  }.contains(status)) {
    return PurchaseGroup.closed;
  }
  if (const {'PAID', 'COMPLETED', 'DELIVERED'}.contains(status)) {
    return PurchaseGroup.completed;
  }
  return PurchaseGroup.active;
}

bool purchaseNeedsPayment(Map<String, dynamic> row) =>
    const {
      'PENDING',
      'PENDING_PAYMENT',
      'UNPAID',
    }.contains((row['status'] ?? '').toString().toUpperCase()) &&
    (row['paymentMethod'] ?? '').toString().toUpperCase() != 'CREDIMPULSO';

String purchaseAmount(Map<String, dynamic> row) {
  num read(String key) =>
      row[key] is num ? row[key] as num : num.tryParse('${row[key]}') ?? 0;
  return (row['type'] ?? '').toString().toUpperCase() == 'QR'
      ? moneyUsd(read('totalUsd'))
      : moneyBs(read('total'));
}

String invoiceAsText(Map<String, dynamic> invoice) {
  num read(Map<dynamic, dynamic> row, String key) =>
      row[key] is num ? row[key] as num : num.tryParse('${row[key]}') ?? 0;
  final lines = (invoice['lines'] as List? ?? const []).whereType<Map>();
  return [
    'Kredi+ · Factura ${invoice['invoiceNumber'] ?? ''}',
    'Fecha: ${dateLabel(invoice['createdAtMillis'])}',
    'Cliente: ${invoice['customerName'] ?? ''}',
    if ('${invoice['fairName'] ?? ''}'.isNotEmpty)
      'Jornada: ${invoice['fairName']}',
    'Método: ${statusLabel(invoice['paymentMethod']?.toString())}',
    '',
    for (final row in lines)
      '${row['quantity']} × ${row['productName']} · ${moneyBs(read(row, 'unitPrice'))} c/u · ${moneyBs(read(row, 'quantity') * read(row, 'unitPrice'))}',
    '',
    'Subtotal: ${moneyBs(read(invoice, 'subtotal'))}',
    'Descuento: ${moneyBs(read(invoice, 'discountAmount'))}',
    'Total: ${moneyBs(read(invoice, 'total'))}',
    if ('${invoice['paymentReference'] ?? ''}'.isNotEmpty)
      'Referencia: ${invoice['paymentReference']}',
  ].join('\n');
}

Map<String, String> paymentDestinationFields(
  Map<String, dynamic> data,
  String method,
  num amountBs,
) {
  Map<String, dynamic> map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  final business = map(data['business']);
  final bank = map(
    data[method == 'BANK_TRANSFER' ? 'bankTransfer' : 'mobilePayment'],
  );
  String first(List<Object?> values) => values
      .map((value) => '${value ?? ''}')
      .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  return {
    'Negocio': first([
      business['commercialName'],
      business['legalName'],
      data['businessName'],
      data['commercialName'],
    ]),
    'Banco': first([bank['bank'], data['bankName'], data['bank']]),
    if (method == 'BANK_TRANSFER')
      'Cuenta': first([bank['accountNumber'], data['accountNumber']]),
    if (method != 'BANK_TRANSFER')
      'Teléfono': first([bank['phone'], data['phone']]),
    'Titular': first([bank['holderName'], data['holderName']]),
    'Cédula/RIF': first([
      bank['identityNumber'],
      business['rif'],
      data['identityNumber'],
    ]),
    'Monto a reportar': moneyBs(amountBs),
  }..removeWhere((key, value) => value.isEmpty);
}

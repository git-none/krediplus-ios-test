/// Métodos de pago externos que el destino autoriza y puede mostrar completos.
/// Acepta PaymentDestinationDto, FairDto o AssociatedBusinessDto del backend.
List<String> availablePaymentMethods(Map<String, dynamic> destination) {
  Map<String, dynamic> object(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
  bool complete(Map<String, dynamic> value, List<String> fields) =>
      fields.every(
        (field) =>
            value[field] is String &&
            (value[field] as String).trim().isNotEmpty,
      );

  final business = object(destination['business']);
  if (destination['active'] == false || business['active'] == false) return [];
  final mode = (destination['paymentMode'] ?? business['paymentMode'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final mobile = object(
    destination.containsKey('mobilePayment')
        ? destination['mobilePayment']
        : business['mobilePayment'],
  );
  final transfer = object(
    destination.containsKey('bankTransfer')
        ? destination['bankTransfer']
        : business['bankTransfer'],
  );
  return [
    if ((mode == 'MOBILE_PAYMENT' || mode == 'BOTH') &&
        complete(mobile, ['bank', 'phone', 'identityNumber', 'holderName']))
      'MOBILE_PAYMENT',
    if ((mode == 'BANK_TRANSFER' || mode == 'BOTH') &&
        complete(transfer, [
          'bank',
          'accountType',
          'accountNumber',
          'identityNumber',
          'holderName',
        ]))
      'BANK_TRANSFER',
  ];
}

/// Lee el monto efectivamente pagado, con hasta dos decimales.
/// Las agrupaciones requieren un separador decimal explícito para evitar que
/// "1,234" se interprete como mil bolívares cuando se quiso escribir una fracción.
double? parseReportedAmountBs(String input) {
  final value = input.trim();
  String normalized;
  if (RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value)) {
    normalized = value.replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(?:\.\d{3})+,\d{1,2}$').hasMatch(value)) {
    normalized = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(?:,\d{3})+\.\d{1,2}$').hasMatch(value)) {
    normalized = value.replaceAll(',', '');
  } else {
    return null;
  }
  final amount = double.tryParse(normalized);
  return amount != null && amount.isFinite && amount > 0 ? amount : null;
}

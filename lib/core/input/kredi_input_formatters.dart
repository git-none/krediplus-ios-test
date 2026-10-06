import 'package:flutter/services.dart';

/// Formatea fechas escritas como DD/MM/AAAA.
/// El usuario introduce únicamente números y los separadores se agregan solos.
class KrediDateInputFormatter extends TextInputFormatter {
  const KrediDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Permite importes numéricos con un único separador decimal.
/// La coma se normaliza a punto para que double.tryParse funcione igual
/// independientemente del teclado del teléfono.
class KrediDecimalInputFormatter extends TextInputFormatter {
  const KrediDecimalInputFormatter({this.decimalDigits = 2});

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = newValue.text.replaceAll(',', '.');
    final filtered = normalized.replaceAll(RegExp(r'[^0-9.]'), '');
    final firstDot = filtered.indexOf('.');

    String result;
    if (firstDot < 0) {
      result = filtered;
    } else {
      final whole = filtered.substring(0, firstDot);
      final fraction = filtered
          .substring(firstDot + 1)
          .replaceAll('.', '');
      final limited = fraction.length > decimalDigits
          ? fraction.substring(0, decimalDigits)
          : fraction;
      result = '$whole.$limited';
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

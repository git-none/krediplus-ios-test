import '../utils/json_read.dart';

class BiweeklyBillingPeriod {
  const BiweeklyBillingPeriod({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String get label => '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} '
      'al ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';
}

class BiweeklyBilling {
  static BiweeklyBillingPeriod currentPeriod([DateTime? value]) {
    final now = (value ?? DateTime.now()).toLocal();
    if (now.day <= 15) {
      return BiweeklyBillingPeriod(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month, 15),
      );
    }
    return BiweeklyBillingPeriod(
      start: DateTime(now.year, now.month, 16),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  static List<Map<String, dynamic>> installmentsForPeriod(
    Iterable<Map<String, dynamic>> installments,
    BiweeklyBillingPeriod period,
  ) => installments.where((row) {
        final due = DateTime.tryParse(jString(row, ['dueDate']));
        return due != null && period.contains(due.toLocal());
      }).toList();

  static double totalUsd(Iterable<Map<String, dynamic>> installments) =>
      installments.fold<double>(0, (sum, row) => sum + jDouble(row, ['amountUsd']));
}

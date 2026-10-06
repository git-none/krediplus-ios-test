class MoneyEngine {
  const MoneyEngine._();

  static double usdToBs(double usd, double bcvRate) {
    if (!usd.isFinite || !bcvRate.isFinite || usd < 0 || bcvRate <= 0) return 0;
    return _round2(usd * bcvRate);
  }

  static double applyPercentDiscount(double amount, double percent) {
    if (amount <= 0 || percent <= 0) return amount;
    return _round2(amount * (1 - (percent.clamp(0, 100) / 100)));
  }

  static double applyFixedDiscount(double amount, double discount) {
    return _round2((amount - discount).clamp(0, double.infinity));
  }

  static double _round2(double value) => (value * 100).roundToDouble() / 100;
}

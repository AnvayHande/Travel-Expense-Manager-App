import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static final _compactFormat = NumberFormat.compactCurrency(
    symbol: '\$',
    decimalDigits: 1,
  );

  static String format(double amount) => _currencyFormat.format(amount);

  static String formatCompact(double amount) => _compactFormat.format(amount);

  static double parse(String value) {
    try {
      return _currencyFormat.parse(value) as double;
    } catch (_) {
      return 0.0;
    }
  }

  static String formatWithSymbol(double amount, {String symbol = '\$'}) {
    final format = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return format.format(amount);
  }
}

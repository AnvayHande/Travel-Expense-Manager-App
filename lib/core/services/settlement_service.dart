import 'dart:math' as math;

class BalanceInfo {
  final String userId;
  final double totalPaid;
  final double totalOwed;
  final double netBalance;

  const BalanceInfo({
    required this.userId,
    required this.totalPaid,
    required this.totalOwed,
    required this.netBalance,
  });

  bool get isSettled => netBalance.abs() < epsilon;
  bool get isCreditor => netBalance > epsilon;
  bool get isDebtor => netBalance < -epsilon;
}

class ParticipantBalance {
  final String userId;
  final double netBalance;

  const ParticipantBalance({
    required this.userId,
    required this.netBalance,
  });

  bool get isSettled => netBalance.abs() < epsilon;
}

class Settlement {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const Settlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settlement &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          (amount - other.amount).abs() < 0.005;

  @override
  int get hashCode => Object.hash(fromUserId, toUserId, amount);

  @override
  String toString() =>
      'Settlement(fromUserId: $fromUserId, toUserId: $toUserId, amount: ${amount.toStringAsFixed(2)})';
}

const double epsilon = 0.01;

class SettlementService {
  List<Settlement> calculateMinimumTransactions(
    List<ParticipantBalance> balances,
  ) {
    if (balances.length < 2) return [];

    final creditors = <_BalanceEntry>[];
    final debtors = <_BalanceEntry>[];

    for (final b in balances) {
      if (b.netBalance > epsilon) {
        creditors.add(_BalanceEntry(b.userId, b.netBalance));
      } else if (b.netBalance < -epsilon) {
        debtors.add(_BalanceEntry(b.userId, -b.netBalance));
      }
    }

    if (creditors.isEmpty || debtors.isEmpty) return [];

    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final transactions = <Settlement>[];
    int ci = 0;
    int di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final creditRemaining = creditors[ci].amount;
      final debitRemaining = debtors[di].amount;

      final transferAmount = _roundToTwoDecimals(
        math.min(creditRemaining, debitRemaining),
      );

      if (transferAmount > epsilon) {
        transactions.add(Settlement(
          fromUserId: debtors[di].userId,
          toUserId: creditors[ci].userId,
          amount: transferAmount,
        ));
      }

      creditors[ci] = _BalanceEntry(
        creditors[ci].userId,
        _roundToTwoDecimals(creditRemaining - transferAmount),
      );
      debtors[di] = _BalanceEntry(
        debtors[di].userId,
        _roundToTwoDecimals(debitRemaining - transferAmount),
      );

      if (creditors[ci].amount < epsilon) ci++;
      if (debtors[di].amount < epsilon) di++;
    }

    return transactions;
  }

  Map<String, double> calculateNetBalances(
    List<ParticipantBalance> balances,
  ) {
    final result = <String, double>{};
    for (final b in balances) {
      result[b.userId] = _roundToTwoDecimals(b.netBalance);
    }
    return result;
  }

  double _roundToTwoDecimals(double value) =>
      (value * 100).roundToDouble() / 100;
}

class _BalanceEntry {
  final String userId;
  final double amount;

  const _BalanceEntry(this.userId, this.amount);
}

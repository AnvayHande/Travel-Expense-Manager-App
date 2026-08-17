import 'package:flutter_test/flutter_test.dart';
import 'package:trip_expense_manager/core/services/settlement_service.dart';

void main() {
  late SettlementService service;

  setUp(() {
    service = SettlementService();
  });

  group('calculateMinimumTransactions', () {
    test('returns empty list for 1 participant', () {
      final balances = [
        ParticipantBalance(userId: 'rahul', netBalance: 1000.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, isEmpty);
    });

    test('returns empty list when all balances are zero', () {
      final balances = [
        ParticipantBalance(userId: 'rahul', netBalance: 0.0),
        ParticipantBalance(userId: 'amit', netBalance: 0.0),
        ParticipantBalance(userId: 'riya', netBalance: 0.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, isEmpty);
    });

    test('returns empty list when all balances within epsilon', () {
      final balances = [
        ParticipantBalance(userId: 'rahul', netBalance: 0.005),
        ParticipantBalance(userId: 'amit', netBalance: -0.005),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, isEmpty);
    });

    test('handles 2 participants correctly', () {
      final balances = [
        ParticipantBalance(userId: 'rahul', netBalance: 500.0),
        ParticipantBalance(userId: 'amit', netBalance: -500.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, hasLength(1));
      expect(result[0].fromUserId, 'amit');
      expect(result[0].toUserId, 'rahul');
      expect(result[0].amount, 500.0);
    });

    test('handles the example: Rahul +4000, Amit -2500, Riya -1500', () {
      final balances = [
        ParticipantBalance(userId: 'rahul', netBalance: 4000.0),
        ParticipantBalance(userId: 'amit', netBalance: -2500.0),
        ParticipantBalance(userId: 'riya', netBalance: -1500.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, hasLength(2));

      expect(result[0].fromUserId, 'amit');
      expect(result[0].toUserId, 'rahul');
      expect(result[0].amount, 2500.0);

      expect(result[1].fromUserId, 'riya');
      expect(result[1].toUserId, 'rahul');
      expect(result[1].amount, 1500.0);
    });

    test('handles multiple creditors and debtors', () {
      final balances = [
        ParticipantBalance(userId: 'a', netBalance: 1000.0),
        ParticipantBalance(userId: 'b', netBalance: 500.0),
        ParticipantBalance(userId: 'c', netBalance: -800.0),
        ParticipantBalance(userId: 'd', netBalance: -700.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      final totalIn = result.fold<double>(0, (s, t) => s + t.amount);
      expect(totalIn, closeTo(1500.0, 0.01));
      expect(result.length, lessThanOrEqualTo(3));
      expect(result.length, greaterThanOrEqualTo(2));

      for (final t in result) {
        expect(t.amount, greaterThan(0));
      }
    });

    test('10 participants with varied balances', () {
      final balances = List.generate(10, (i) {
        return ParticipantBalance(
          userId: 'user$i',
          netBalance: (i % 3 == 0)
              ? 1000.0
              : (i % 3 == 1)
                  ? -500.0
                  : 0.0,
        );
      });

      final result = service.calculateMinimumTransactions(balances);

      for (final t in result) {
        expect(t.amount, greaterThan(0));
        expect(t.fromUserId, isNot(t.toUserId));
      }
    });

    test('ignores participants with zero balance', () {
      final balances = [
        ParticipantBalance(userId: 'creditor', netBalance: 300.0),
        ParticipantBalance(userId: 'debtor', netBalance: -300.0),
        ParticipantBalance(userId: 'bystander', netBalance: 0.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, hasLength(1));
      expect(result[0].fromUserId, 'debtor');
      expect(result[0].toUserId, 'creditor');
      expect(result[0].amount, 300.0);
    });

    test('rounds amounts to 2 decimal places', () {
      final balances = [
        ParticipantBalance(userId: 'a', netBalance: 100.33333),
        ParticipantBalance(userId: 'b', netBalance: -100.33333),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result, hasLength(1));
      expect(result[0].amount, 100.33);
    });

    test('produces minimum number of transactions for complex case', () {
      final balances = [
        ParticipantBalance(userId: 'a', netBalance: 1500.0),
        ParticipantBalance(userId: 'b', netBalance: 500.0),
        ParticipantBalance(userId: 'c', netBalance: -1200.0),
        ParticipantBalance(userId: 'd', netBalance: -800.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      expect(result.length, lessThan(4));
      expect(result.length, greaterThan(0));
    });

    test('never creates transactions from creditor to debtor', () {
      final balances = [
        ParticipantBalance(userId: 'high', netBalance: 1000.0),
        ParticipantBalance(userId: 'low', netBalance: -1000.0),
      ];

      final result = service.calculateMinimumTransactions(balances);

      for (final t in result) {
        final fromBalance =
            balances.firstWhere((b) => b.userId == t.fromUserId);
        final toBalance =
            balances.firstWhere((b) => b.userId == t.toUserId);
        expect(fromBalance.netBalance, lessThan(0));
        expect(toBalance.netBalance, greaterThan(0));
      }
    });

    test('handles 1 creditor and many debtors with precision', () {
      final balances = [
        ParticipantBalance(userId: 'creditor', netBalance: 100.0),
        ParticipantBalance(userId: 'debtor1', netBalance: -33.33),
        ParticipantBalance(userId: 'debtor2', netBalance: -33.33),
        ParticipantBalance(userId: 'debtor3', netBalance: -33.34),
      ];

      final result = service.calculateMinimumTransactions(balances);

      final totalPaid =
          result.fold<double>(0, (s, t) => s + t.amount);

      expect(totalPaid, closeTo(100.0, 0.01));

      for (final t in result) {
        expect(t.toUserId, 'creditor');
      }
    });

    test('handles many debtors 1 creditor 10 participants', () {
      final balances = [
        ParticipantBalance(userId: 'rich', netBalance: 5000.0),
        ...List.generate(9, (i) => ParticipantBalance(
              userId: 'poor$i',
              netBalance: -5000.0 / 9,
            )),
      ];

      final result = service.calculateMinimumTransactions(balances);

      final totalPaid =
          result.fold<double>(0, (s, t) => s + t.amount);

      expect(totalPaid, closeTo(5000.0, 1.0));

      for (final t in result) {
        expect(t.toUserId, 'rich');
        expect(t.amount, greaterThan(0));
      }
    });

    test('handles many creditors 1 debtor 10 participants', () {
      final balances = [
        ParticipantBalance(userId: 'poor', netBalance: -5000.0),
        ...List.generate(9, (i) => ParticipantBalance(
              userId: 'rich$i',
              netBalance: 5000.0 / 9,
            )),
      ];

      final result = service.calculateMinimumTransactions(balances);

      final totalPaid =
          result.fold<double>(0, (s, t) => s + t.amount);

      expect(totalPaid, closeTo(5000.0, 1.0));

      for (final t in result) {
        expect(t.fromUserId, 'poor');
        expect(t.amount, greaterThan(0));
      }
    });

    test('100 participants with random balances stays within limit', () {
      final balances = List.generate(100, (i) {
        final sign = (i % 2 == 0) ? 1.0 : -1.0;
        return ParticipantBalance(
          userId: 'user$i',
          netBalance: sign * 100.0,
        );
      });

      final result = service.calculateMinimumTransactions(balances);

      expect(result.length, lessThanOrEqualTo(100));
      expect(result.length, greaterThan(0));

      for (final t in result) {
        expect(t.amount, greaterThan(0));
      }
    });
  });

  group('calculateNetBalances', () {
    test('returns correct net balance map', () {
      final balances = [
        ParticipantBalance(userId: 'a', netBalance: 500.0),
        ParticipantBalance(userId: 'b', netBalance: -300.0),
        ParticipantBalance(userId: 'c', netBalance: -200.0),
      ];

      final result = service.calculateNetBalances(balances);

      expect(result, hasLength(3));
      expect(result['a'], 500.0);
      expect(result['b'], -300.0);
      expect(result['c'], -200.0);
    });

    test('rounds values to 2 decimal places', () {
      final balances = [
        ParticipantBalance(userId: 'a', netBalance: 100.56789),
        ParticipantBalance(userId: 'b', netBalance: -100.56789),
      ];

      final result = service.calculateNetBalances(balances);

      expect(result['a'], 100.57);
      expect(result['b'], -100.57);
    });
  });

  group('Settlement equality', () {
    test('equal settlements are equal', () {
      final a = Settlement(fromUserId: 'x', toUserId: 'y', amount: 100.0);
      final b = Settlement(fromUserId: 'x', toUserId: 'y', amount: 100.0);

      expect(a, equals(b));
    });

    test('different amounts are not equal', () {
      final a = Settlement(fromUserId: 'x', toUserId: 'y', amount: 100.0);
      final b = Settlement(fromUserId: 'x', toUserId: 'y', amount: 200.0);

      expect(a, isNot(equals(b)));
    });

    test('amounts within 0.005 are considered equal', () {
      final a = Settlement(fromUserId: 'x', toUserId: 'y', amount: 100.0);
      final b = Settlement(fromUserId: 'x', toUserId: 'y', amount: 100.003);

      expect(a, equals(b));
    });
  });
}

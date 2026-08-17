import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'split_detail.dart';

class ExpenseModel extends Equatable {
  final String expenseId;
  final String tripId;
  final String expenseName;
  final String? description;
  final double amount;
  final String paidBy;
  final String splitType;
  final List<SplitDetail> splitDetails;
  final String category;
  final DateTime createdAt;
  final String? notes;
  final String? receiptUrl;

  const ExpenseModel({
    required this.expenseId,
    required this.tripId,
    required this.expenseName,
    this.description,
    required this.amount,
    required this.paidBy,
    this.splitType = 'equal',
    this.splitDetails = const [],
    required this.category,
    required this.createdAt,
    this.notes,
    this.receiptUrl,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final splitBetweenRaw = json['splitBetween'];
    final splitTypeRaw = json['splitType'] as String?;
    final splitDetailsRaw = json['splitDetails'];

    List<SplitDetail> details;
    String type;

    if (splitDetailsRaw != null) {
      type = splitTypeRaw ?? 'equal';
      details = (splitDetailsRaw as List<dynamic>)
          .map((e) => SplitDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (splitBetweenRaw != null) {
      type = 'equal';
      details = (splitBetweenRaw as List<dynamic>)
          .map((e) => SplitDetail(userId: e as String))
          .toList();
    } else {
      type = 'paidOnly';
      details = [];
    }

    return ExpenseModel(
      expenseId: json['expenseId'] as String,
      tripId: json['tripId'] as String,
      expenseName: json['expenseName'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      paidBy: json['paidBy'] as String,
      splitType: type,
      splitDetails: details,
      category: json['category'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      notes: json['notes'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expenseId': expenseId,
      'tripId': tripId,
      'expenseName': expenseName,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splitType': splitType,
      'splitDetails': splitDetails.map((d) => d.toJson()).toList(),
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'receiptUrl': receiptUrl,
    };
  }

  ExpenseModel copyWith({
    String? expenseId,
    String? tripId,
    String? expenseName,
    String? description,
    double? amount,
    String? paidBy,
    String? splitType,
    List<SplitDetail>? splitDetails,
    String? category,
    DateTime? createdAt,
    String? notes,
    String? receiptUrl,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      tripId: tripId ?? this.tripId,
      expenseName: expenseName ?? this.expenseName,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      splitType: splitType ?? this.splitType,
      splitDetails: splitDetails ?? this.splitDetails,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }

  List<String> get splitBetween =>
      splitDetails.map((d) => d.userId).toList();

  double splitAmountForUser(String userId) {
    final detail = splitDetails.where((d) => d.userId == userId).firstOrNull;
    if (detail == null) return 0;

    switch (splitType) {
      case 'exact':
        return detail.amount ?? 0;
      case 'percentage':
        return amount * ((detail.percentage ?? 0) / 100);
      case 'shares':
        final totalShares =
            splitDetails.fold<int>(0, (acc, d) => acc + (d.shares ?? 0));
        if (totalShares == 0) return 0;
        return amount * ((detail.shares ?? 0) / totalShares);
      case 'paidOnly':
        return userId == paidBy ? amount : 0;
      case 'equal':
      default:
        final count = splitDetails.length;
        return count > 0 ? amount / count : amount;
    }
  }

  double get splitAmount {
    if (splitType == 'paidOnly') return amount;
    final count = splitDetails.length;
    return count > 0 ? amount / count : amount;
  }

  String get splitLabel {
    switch (splitType) {
      case 'exact':
        return 'Exact split';
      case 'percentage':
        return 'Percentage split';
      case 'shares':
        return 'Share split';
      case 'paidOnly':
        return 'Paid only';
      case 'equal':
      default:
        return splitDetails.length > 1
            ? '${splitDetails.length}-way split'
            : 'Equal split';
    }
  }

  @override
  List<Object?> get props => [
        expenseId,
        tripId,
        expenseName,
        description,
        amount,
        paidBy,
        splitType,
        splitDetails,
        category,
        createdAt,
        notes,
        receiptUrl,
      ];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SettlementModel extends Equatable {
  final String settlementId;
  final String tripId;
  final String fromUser;
  final String toUser;
  final double amount;
  final String status;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;

  const SettlementModel({
    required this.settlementId,
    required this.tripId,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    this.status = 'pending',
    this.completedAt,
    this.completedBy,
    required this.createdAt,
  });

  bool get isSettled => status == 'completed';

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      settlementId: json['settlementId'] as String,
      tripId: json['tripId'] as String,
      fromUser: json['fromUser'] as String,
      toUser: json['toUser'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
      completedBy: json['completedBy'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settlementId': settlementId,
      'tripId': tripId,
      'fromUser': fromUser,
      'toUser': toUser,
      'amount': amount,
      'status': status,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completedBy': completedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SettlementModel copyWith({
    String? settlementId,
    String? tripId,
    String? fromUser,
    String? toUser,
    double? amount,
    String? status,
    DateTime? completedAt,
    String? completedBy,
    DateTime? createdAt,
  }) {
    return SettlementModel(
      settlementId: settlementId ?? this.settlementId,
      tripId: tripId ?? this.tripId,
      fromUser: fromUser ?? this.fromUser,
      toUser: toUser ?? this.toUser,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        settlementId,
        tripId,
        fromUser,
        toUser,
        amount,
        status,
        completedAt,
        completedBy,
        createdAt,
      ];
}

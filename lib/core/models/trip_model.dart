import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class TripModel extends Equatable {
  final String tripId;
  final String tripName;
  final String? destination;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String currency;
  final String adminId;
  final String adminName;
  final String? inviteCode;
  final List<String> participants;
  final String status;
  final double totalBudget;
  final DateTime createdAt;

  const TripModel({
    required this.tripId,
    required this.tripName,
    this.destination,
    this.description,
    this.startDate,
    this.endDate,
    this.currency = 'USD',
    required this.adminId,
    required this.adminName,
    this.inviteCode,
    this.participants = const [],
    this.status = 'active',
    this.totalBudget = 0,
    required this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      tripId: json['tripId'] as String,
      tripName: json['tripName'] as String,
      destination: json['destination'] as String?,
      description: json['description'] as String?,
      startDate: json['startDate'] != null
          ? (json['startDate'] as Timestamp).toDate()
          : null,
      endDate: json['endDate'] != null
          ? (json['endDate'] as Timestamp).toDate()
          : null,
      currency: json['currency'] as String? ?? 'USD',
      adminId: json['adminId'] as String,
      adminName: json['adminName'] as String? ?? '',
      inviteCode: json['inviteCode'] as String?,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'active',
      totalBudget: (json['totalBudget'] as num?)?.toDouble() ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripId': tripId,
      'tripName': tripName,
      'destination': destination,
      'description': description,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'currency': currency,
      'adminId': adminId,
      'adminName': adminName,
      'inviteCode': inviteCode,
      'participants': participants,
      'status': status,
      'totalBudget': totalBudget,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TripModel copyWith({
    String? tripId,
    String? tripName,
    String? destination,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? currency,
    String? adminId,
    String? adminName,
    String? inviteCode,
    List<String>? participants,
    String? status,
    double? totalBudget,
    DateTime? createdAt,
  }) {
    return TripModel(
      tripId: tripId ?? this.tripId,
      tripName: tripName ?? this.tripName,
      destination: destination ?? this.destination,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currency: currency ?? this.currency,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      inviteCode: inviteCode ?? this.inviteCode,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      totalBudget: totalBudget ?? this.totalBudget,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isActive => status == 'active';
  bool isAdmin(String userId) => adminId == userId;
  bool isParticipant(String userId) => participants.contains(userId);

  @override
  List<Object?> get props => [
        tripId,
        tripName,
        destination,
        description,
        startDate,
        endDate,
        currency,
        adminId,
        adminName,
        inviteCode,
        participants,
        status,
        totalBudget,
        createdAt,
      ];
}

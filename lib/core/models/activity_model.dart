import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ActivityModel extends Equatable {
  final String activityId;
  final String tripId;
  final String userId;
  final String userName;
  final String actionType;
  final String message;
  final DateTime createdAt;

  const ActivityModel({
    required this.activityId,
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.actionType,
    required this.message,
    required this.createdAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      activityId: json['activityId'] as String,
      tripId: json['tripId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String? ?? '',
      actionType: json['actionType'] as String,
      message: json['message'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activityId': activityId,
      'tripId': tripId,
      'userId': userId,
      'userName': userName,
      'actionType': actionType,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [
        activityId,
        tripId,
        userId,
        userName,
        actionType,
        message,
        createdAt,
      ];
}

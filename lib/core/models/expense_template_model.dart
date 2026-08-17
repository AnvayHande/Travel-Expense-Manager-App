import 'package:equatable/equatable.dart';

class ExpenseTemplateModel extends Equatable {
  final String templateId;
  final String userId;
  final String? tripId;
  final String name;
  final String category;
  final String splitType;
  final String? notes;
  final bool favorite;
  final int usageCount;
  final DateTime createdAt;

  const ExpenseTemplateModel({
    required this.templateId,
    required this.userId,
    this.tripId,
    required this.name,
    required this.category,
    this.splitType = 'equal',
    this.notes,
    this.favorite = false,
    this.usageCount = 0,
    required this.createdAt,
  });

  factory ExpenseTemplateModel.fromJson(Map<String, dynamic> json) {
    return ExpenseTemplateModel(
      templateId: json['templateId'] as String,
      userId: json['userId'] as String,
      tripId: json['tripId'] as String?,
      name: json['name'] as String,
      category: json['category'] as String,
      splitType: json['splitType'] as String? ?? 'equal',
      notes: json['notes'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'userId': userId,
      'tripId': tripId,
      'name': name,
      'category': category,
      'splitType': splitType,
      'notes': notes,
      'favorite': favorite,
      'usageCount': usageCount,
      'createdAt': createdAt,
    };
  }

  ExpenseTemplateModel copyWith({
    String? templateId,
    String? userId,
    String? tripId,
    String? name,
    String? category,
    String? splitType,
    String? notes,
    bool? favorite,
    int? usageCount,
    DateTime? createdAt,
    bool clearTripId = false,
  }) {
    return ExpenseTemplateModel(
      templateId: templateId ?? this.templateId,
      userId: userId ?? this.userId,
      tripId: clearTripId ? null : (tripId ?? this.tripId),
      name: name ?? this.name,
      category: category ?? this.category,
      splitType: splitType ?? this.splitType,
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        templateId,
        userId,
        tripId,
        name,
        category,
        splitType,
        notes,
        favorite,
        usageCount,
        createdAt,
      ];
}

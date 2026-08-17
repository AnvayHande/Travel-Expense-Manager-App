import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class CategoryModel extends Equatable {
  final String categoryId;
  final String tripId;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final double budget;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;

  const CategoryModel({
    required this.categoryId,
    required this.tripId,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.budget = 0,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      categoryId: json['categoryId'] as String,
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int? ?? Icons.receipt_long_rounded.codePoint,
      colorValue: json['colorValue'] as int? ?? Colors.grey.toARGB32(),
      budget: (json['budget'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: (json['createdAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'tripId': tripId,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'budget': budget,
      'isDefault': isDefault,
      'isArchived': isArchived,
      'createdAt': createdAt,
    };
  }

  CategoryModel copyWith({
    String? categoryId,
    String? tripId,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    double? budget,
    bool? isDefault,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      budget: budget ?? this.budget,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  static List<CategoryModel> defaultsForTrip(String tripId) {
    final now = DateTime.now();
    return [
      CategoryModel(
        categoryId: '${tripId}_food',
        tripId: tripId,
        name: 'Food',
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        colorValue: Colors.orange.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_transport',
        tripId: tripId,
        name: 'Transport',
        iconCodePoint: Icons.directions_car_rounded.codePoint,
        colorValue: Colors.blue.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_accommodation',
        tripId: tripId,
        name: 'Accommodation',
        iconCodePoint: Icons.hotel_rounded.codePoint,
        colorValue: Colors.purple.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_activities',
        tripId: tripId,
        name: 'Activities',
        iconCodePoint: Icons.sports_esports_rounded.codePoint,
        colorValue: Colors.teal.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_shopping',
        tripId: tripId,
        name: 'Shopping',
        iconCodePoint: Icons.shopping_bag_rounded.codePoint,
        colorValue: Colors.pink.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_utilities',
        tripId: tripId,
        name: 'Utilities',
        iconCodePoint: Icons.build_rounded.codePoint,
        colorValue: Colors.brown.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_healthcare',
        tripId: tripId,
        name: 'Healthcare',
        iconCodePoint: Icons.medical_services_rounded.codePoint,
        colorValue: Colors.red.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_entertainment',
        tripId: tripId,
        name: 'Entertainment',
        iconCodePoint: Icons.movie_rounded.codePoint,
        colorValue: Colors.indigo.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
      CategoryModel(
        categoryId: '${tripId}_other',
        tripId: tripId,
        name: 'Other',
        iconCodePoint: Icons.receipt_long_rounded.codePoint,
        colorValue: Colors.grey.toARGB32(),
        isDefault: true,
        createdAt: now,
      ),
    ];
  }

  @override
  List<Object?> get props => [
        categoryId,
        tripId,
        name,
        iconCodePoint,
        colorValue,
        budget,
        isDefault,
        isArchived,
        createdAt,
      ];
}

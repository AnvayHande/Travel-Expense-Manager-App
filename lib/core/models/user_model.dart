import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastLogin: json['lastLogin'] != null
          ? (json['lastLogin'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  List<Object?> get props =>
      [uid, name, email, phone, photoUrl, createdAt, lastLogin];
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ParticipantModel extends Equatable {
  final String uid;
  final String name;
  final String? email;
  final DateTime joinedAt;

  const ParticipantModel({
    required this.uid,
    required this.name,
    this.email,
    required this.joinedAt,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      joinedAt: (json['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  ParticipantModel copyWith({
    String? uid,
    String? name,
    String? email,
    DateTime? joinedAt,
  }) {
    return ParticipantModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  List<Object?> get props => [uid, name, email, joinedAt];
}

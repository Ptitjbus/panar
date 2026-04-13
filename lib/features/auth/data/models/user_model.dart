import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_entity.dart';

/// User model that extends UserEntity and handles data serialization
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.createdAt,
    super.userMetadata,
  });

  /// Creates a UserModel from a Supabase User object
  factory UserModel.fromSupabaseUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      createdAt: DateTime.parse(user.createdAt),
      userMetadata: user.userMetadata,
    );
  }

  /// Creates a UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userMetadata: json['user_metadata'] as Map<String, dynamic>?,
    );
  }

  /// Converts UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'user_metadata': userMetadata,
    };
  }

  /// Converts UserModel to UserEntity
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      createdAt: createdAt,
      userMetadata: userMetadata,
    );
  }
}

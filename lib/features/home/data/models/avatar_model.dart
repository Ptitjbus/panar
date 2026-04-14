import '../../domain/entities/avatar_entity.dart';

/// Avatar model that extends AvatarEntity and handles data serialization
class AvatarModel extends AvatarEntity {
  const AvatarModel({
    required super.id,
    required super.userId,
    super.displayName,
    required super.colorHex,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Creates an AvatarModel from JSON
  factory AvatarModel.fromJson(Map<String, dynamic> json) {
    return AvatarModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      colorHex: json['color_hex'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts AvatarModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts AvatarModel to AvatarEntity
  AvatarEntity toEntity() {
    return AvatarEntity(
      id: id,
      userId: userId,
      displayName: displayName,
      colorHex: colorHex,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

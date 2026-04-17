import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({required super.id, required super.email});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(id: json['id'] as String, email: json['email'] as String);
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email};
}

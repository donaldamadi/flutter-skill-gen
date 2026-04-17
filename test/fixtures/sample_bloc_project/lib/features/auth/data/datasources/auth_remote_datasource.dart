import '../../domain/entities/user_entity.dart';

abstract class AuthRemoteDatasource {
  Future<UserEntity> login({required String email, required String password});
}

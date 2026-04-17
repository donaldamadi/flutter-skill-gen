import 'package:dartz/dartz.dart';

import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUsecase {
  const LoginUsecase({required this.repository});

  final AuthRepository repository;

  Future<Either<String, UserEntity>> call({
    required String email,
    required String password,
  }) {
    return repository.login(email: email, password: password);
  }
}

import 'package:dartz/dartz.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.remoteDatasource});

  final AuthRemoteDatasource remoteDatasource;

  @override
  Future<Either<String, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await remoteDatasource.login(
        email: email,
        password: password,
      );
      return Right(user);
    } catch (e) {
      return Left(e.toString());
    }
  }
}

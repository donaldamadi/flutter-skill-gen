import 'package:dartz/dartz.dart';

import '../../domain/entities/feed_item_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({required this.remoteDatasource});

  final HomeRemoteDatasource remoteDatasource;

  @override
  Future<Either<String, List<FeedItemEntity>>> fetchFeed() async {
    try {
      final items = await remoteDatasource.fetchFeed();
      return Right(items);
    } catch (e) {
      return Left(e.toString());
    }
  }
}

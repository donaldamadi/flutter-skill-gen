import 'package:dartz/dartz.dart';

import '../entities/feed_item_entity.dart';
import '../repositories/home_repository.dart';

class FetchFeedUsecase {
  const FetchFeedUsecase(this.repository);

  final HomeRepository repository;

  Future<Either<String, List<FeedItemEntity>>> call() {
    return repository.fetchFeed();
  }
}

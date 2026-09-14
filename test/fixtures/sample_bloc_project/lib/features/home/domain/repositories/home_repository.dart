import 'package:dartz/dartz.dart';

import '../entities/feed_item_entity.dart';

abstract class HomeRepository {
  Future<Either<String, List<FeedItemEntity>>> fetchFeed();
}

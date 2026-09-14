import '../../domain/entities/feed_item_entity.dart';

abstract class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoaded extends HomeState {
  const HomeLoaded(this.items);

  final List<FeedItemEntity> items;
}

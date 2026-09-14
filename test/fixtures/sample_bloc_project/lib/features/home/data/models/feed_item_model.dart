import '../../domain/entities/feed_item_entity.dart';

class FeedItemModel extends FeedItemEntity {
  const FeedItemModel({required super.id, required super.title});

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    return FeedItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }
}

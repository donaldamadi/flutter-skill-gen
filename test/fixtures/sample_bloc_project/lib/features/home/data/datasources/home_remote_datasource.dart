import '../../../../core/network/api_client.dart';
import '../models/feed_item_model.dart';

class HomeRemoteDatasource {
  const HomeRemoteDatasource(this.client);

  final ApiClient client;

  Future<List<FeedItemModel>> fetchFeed() async {
    final response = await client.get('/feed');
    return (response as List<dynamic>)
        .map((e) => FeedItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/fetch_feed_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this.fetchFeedUsecase) : super(const HomeInitial()) {
    on<HomeFeedRequested>((event, emit) async {
      final result = await fetchFeedUsecase();
      result.fold((_) => null, (items) => emit(HomeLoaded(items)));
    });
  }

  final FetchFeedUsecase fetchFeedUsecase;
}

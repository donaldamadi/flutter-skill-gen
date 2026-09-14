import 'package:flutter_bloc/flutter_bloc.dart';

import 'cart_event.dart';
import 'cart_state.dart';

/// Deliberately has no data/ or domain/ layer — this feature holds
/// UI state only, and the fixture relies on that to prove layer
/// detection is per-feature rather than project-wide.
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartInitial()) {
    on<CartItemAdded>((event, emit) {
      emit(CartUpdated([..._productIds..add(event.productId)]));
    });
  }

  final List<String> _productIds = [];
}

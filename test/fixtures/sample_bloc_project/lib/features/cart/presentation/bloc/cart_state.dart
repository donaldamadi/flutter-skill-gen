abstract class CartState {
  const CartState();
}

class CartInitial extends CartState {
  const CartInitial();
}

class CartUpdated extends CartState {
  const CartUpdated(this.productIds);

  final List<String> productIds;
}

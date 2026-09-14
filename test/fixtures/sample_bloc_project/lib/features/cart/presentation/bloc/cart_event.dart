abstract class CartEvent {
  const CartEvent();
}

class CartItemAdded extends CartEvent {
  const CartItemAdded(this.productId);

  final String productId;
}

/// Whether the user has acquired the supply an intervention needs. Keyed by
/// [interventionId]; one row per shoppable intervention. Immutable.
class ShoppingState {
  final String interventionId;
  final bool purchased;
  final DateTime? purchasedAt;

  const ShoppingState({
    required this.interventionId,
    required this.purchased,
    this.purchasedAt,
  });

  @override
  bool operator ==(Object other) =>
      other is ShoppingState &&
      other.interventionId == interventionId &&
      other.purchased == purchased &&
      other.purchasedAt == purchasedAt;

  @override
  int get hashCode => Object.hash(interventionId, purchased, purchasedAt);
}

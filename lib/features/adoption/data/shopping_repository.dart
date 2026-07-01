import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/domain/shopping_state.dart';
import 'package:drift/drift.dart';

/// Persistence for per-intervention [ShoppingState]. `interventionId` is the
/// primary key, so a plain insert-or-update upsert suffices.
class ShoppingRepository {
  ShoppingRepository(this._db);
  final AppDatabase _db;

  Future<void> setPurchased(
    String interventionId, {
    required bool purchased,
    DateTime? purchasedAt,
  }) =>
      _db.into(_db.shoppingStates).insertOnConflictUpdate(
            ShoppingStatesCompanion.insert(
              interventionId: interventionId,
              purchased: Value(purchased),
              purchasedAt: Value(purchasedAt),
            ),
          );

  Future<ShoppingState?> byInterventionId(String interventionId) async {
    final row = await (_db.select(_db.shoppingStates)
          ..where((t) => t.interventionId.equals(interventionId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<ShoppingState>> getAll() async =>
      (await _db.select(_db.shoppingStates).get()).map(_fromRow).toList();

  ShoppingState _fromRow(ShoppingStateRow r) => ShoppingState(
        interventionId: r.interventionId,
        purchased: r.purchased,
        purchasedAt: r.purchasedAt,
      );
}

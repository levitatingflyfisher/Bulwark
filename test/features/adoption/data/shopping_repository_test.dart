import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/shopping_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ShoppingRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ShoppingRepository(db);
  });
  tearDown(() => db.close());

  test('setPurchased persists purchased + timestamp', () async {
    final at = DateTime(2026, 1, 5, 10);
    await repo.setPurchased('magnesium', purchased: true, purchasedAt: at);
    final got = await repo.byInterventionId('magnesium');
    expect(got, isNotNull);
    expect(got!.purchased, isTrue);
    expect(got.purchasedAt, at);
  });

  test('toggling purchased updates the single row', () async {
    await repo.setPurchased('magnesium', purchased: true);
    await repo.setPurchased('magnesium', purchased: false);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.purchased, isFalse);
  });

  test('byInterventionId is null when absent', () async {
    expect(await repo.byInterventionId('nope'), isNull);
  });
}

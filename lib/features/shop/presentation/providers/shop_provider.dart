import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/shop_remote_datasource.dart';
import '../../domain/entities/owned_shop_item_entity.dart';
import '../../domain/entities/shop_item_entity.dart';

class ShopData {
  final int balance;
  final List<ShopItemEntity> items;

  const ShopData({required this.balance, required this.items});
}

final shopDataProvider = FutureProvider<ShopData>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return const ShopData(balance: 0, items: []);
  }

  final dataSource = ref.watch(shopRemoteDataSourceProvider);
  final results = await Future.wait<dynamic>([
    dataSource.getUserPetonsBalance(user.id),
    dataSource.getShopItems(),
  ]);
  final balance = results[0] as int;
  final items = (results[1] as List).cast<ShopItemEntity>();
  return ShopData(balance: balance, items: items);
});

class ShopPurchaseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ShopPurchaseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<int?> purchaseItem(String itemId) async {
    state = const AsyncValue.loading();
    try {
      final dataSource = _ref.read(shopRemoteDataSourceProvider);
      final newBalance = await dataSource.purchaseItem(itemId: itemId);
      state = const AsyncValue.data(null);
      _ref.invalidate(shopDataProvider);
      return newBalance;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final shopPurchaseProvider =
    StateNotifierProvider<ShopPurchaseNotifier, AsyncValue<void>>((ref) {
      return ShopPurchaseNotifier(ref);
    });

final ownedShopItemsProvider = FutureProvider<List<OwnedShopItemEntity>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const [];

  final dataSource = ref.watch(shopRemoteDataSourceProvider);
  final items = await dataSource.getOwnedItems(user.id);
  return items.cast<OwnedShopItemEntity>();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/owned_shop_item_model.dart';
import '../models/shop_item_model.dart';

class ShopRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ShopRemoteDataSource(this._supabaseClient);

  Future<int> getUserPetonsBalance(String userId) async {
    try {
      final response = await _supabaseClient
          .from('profiles')
          .select('petons_balance')
          .eq('id', userId)
          .single();

      return _parseInt(response['petons_balance']);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get balance: $e');
    }
  }

  Future<List<ShopItemModel>> getShopItems() async {
    try {
      final raw = await _supabaseClient.rpc('get_shop_catalog');
      final rows = _extractRows(raw);
      if (rows.isNotEmpty) {
        return rows
            .map((json) => ShopItemModel.fromJson(json))
            .where((item) => item.isActive)
            .toList();
      }
    } on PostgrestException {
      // Fallback to direct table query below.
    } catch (_) {
      // Fallback to direct table query below.
    }

    final fetchers = <Future<dynamic> Function()>[
      () => _supabaseClient
          .from('shop_items')
          .select()
          .eq('is_active', true)
          .order('category')
          .order('price_petons')
          .order('name'),
      () => _supabaseClient.rpc('get_shop_items'),
    ];

    DatabaseFailure? lastError;

    for (final fetch in fetchers) {
      try {
        final raw = await fetch();
        final rows = _extractRows(raw);
        final items = rows
            .map((json) => ShopItemModel.fromJson(json))
            .where((item) => item.isActive)
            .toList();
        if (items.isNotEmpty) return items;
      } on PostgrestException catch (e) {
        lastError = DatabaseFailure(e.message);
      } catch (e) {
        lastError = DatabaseFailure('Failed to fetch shop items: $e');
      }
    }

    if (lastError != null) throw lastError;
    return const [];
  }

  Future<int> purchaseItem({required String itemId}) async {
    try {
      final result = await _supabaseClient.rpc(
        'purchase_shop_item',
        params: {'item_id_input': itemId},
      );

      if (result is Map<String, dynamic>) {
        return _parseInt(result['new_balance']);
      }

      throw const DatabaseFailure('Invalid purchase response.');
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to purchase item: $e');
    }
  }

  Future<List<OwnedShopItemModel>> getOwnedItems(String userId) async {
    try {
      final response = await _supabaseClient
          .from('shop_purchases')
          .select(
            'id, price_paid_petons, purchased_at, item:shop_items!inner(id, name, description, category, price_petons, is_active)',
          )
          .eq('user_id', userId)
          .order('purchased_at', ascending: false);

      return _extractRows(
        response,
      ).map((row) => OwnedShopItemModel.fromJson(row)).toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to fetch owned items: $e');
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList();
    }

    if (raw is Map<String, dynamic>) {
      if (raw['data'] is List) {
        final dataRows = raw['data'] as List;
        return dataRows
            .whereType<Map>()
            .map((entry) => entry.cast<String, dynamic>())
            .toList();
      }
      return [raw];
    }

    return const [];
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

final shopRemoteDataSourceProvider = Provider<ShopRemoteDataSource>((ref) {
  return ShopRemoteDataSource(ref.watch(supabaseClientProvider));
});

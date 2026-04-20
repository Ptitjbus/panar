import '../../domain/entities/owned_shop_item_entity.dart';

class OwnedShopItemModel extends OwnedShopItemEntity {
  const OwnedShopItemModel({
    required super.purchaseId,
    required super.itemId,
    required super.name,
    required super.description,
    required super.category,
    required super.pricePaidPetons,
    required super.purchasedAt,
  });

  factory OwnedShopItemModel.fromJson(Map<String, dynamic> json) {
    final item = (json['item'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OwnedShopItemModel(
      purchaseId: (json['id'] ?? '').toString(),
      itemId: (item['id'] ?? '').toString(),
      name: (item['name'] ?? 'Article').toString(),
      description: (item['description'] ?? '').toString(),
      category: (item['category'] ?? '').toString(),
      pricePaidPetons: _parseInt(json['price_paid_petons']),
      purchasedAt:
          DateTime.tryParse((json['purchased_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

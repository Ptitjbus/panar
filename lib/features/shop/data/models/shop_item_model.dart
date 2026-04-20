import '../../domain/entities/shop_item_entity.dart';

class ShopItemModel extends ShopItemEntity {
  const ShopItemModel({
    required super.id,
    required super.name,
    required super.description,
    required super.category,
    required super.pricePetons,
    required super.isActive,
  });

  factory ShopItemModel.fromJson(Map<String, dynamic> json) {
    final rawPrice =
        json['price_petons'] ??
        json['price'] ??
        json['cost_petons'] ??
        json['petons_price'] ??
        json['amount'] ??
        0;
    final parsedPrice = _parseInt(rawPrice);

    return ShopItemModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Article').toString(),
      description:
          (json['description'] ?? json['subtitle'] ?? json['details'] ?? '')
              .toString(),
      category:
          (json['category'] ??
                  json['type'] ??
                  json['kind'] ??
                  json['item_type'] ??
                  'pansement')
              .toString(),
      pricePetons: parsedPrice,
      isActive: _parseBool(
        json['is_active'] ?? json['active'] ?? json['enabled'] ?? true,
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  ShopItemEntity toEntity() {
    return ShopItemEntity(
      id: id,
      name: name,
      description: description,
      category: category,
      pricePetons: pricePetons,
      isActive: isActive,
    );
  }
}

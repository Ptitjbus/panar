/// Shop item entity displayed in the in-app store.
class ShopItemEntity {
  final String id;
  final String name;
  final String description;
  final String category;
  final int pricePetons;
  final bool isActive;

  const ShopItemEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pricePetons,
    required this.isActive,
  });
}

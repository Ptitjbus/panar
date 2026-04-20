class OwnedShopItemEntity {
  final String purchaseId;
  final String itemId;
  final String name;
  final String description;
  final String category;
  final int pricePaidPetons;
  final DateTime purchasedAt;

  const OwnedShopItemEntity({
    required this.purchaseId,
    required this.itemId,
    required this.name,
    required this.description,
    required this.category,
    required this.pricePaidPetons,
    required this.purchasedAt,
  });
}

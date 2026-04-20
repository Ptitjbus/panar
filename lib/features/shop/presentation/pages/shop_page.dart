import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/panar_breadcrumb.dart';
import '../../../../shared/widgets/panar_button.dart';
import '../../domain/entities/shop_item_entity.dart';
import '../providers/shop_provider.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  int _selectedTab = 0;
  static const _tabs = ['Pansement', 'La banque 💡', 'Cosmétiques'];

  Future<void> _handlePurchase(_ShopItem item) async {
    if (item.price == null || item.price! <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet article sera bientôt disponible.')),
      );
      return;
    }

    final newBalance = await ref
        .read(shopPurchaseProvider.notifier)
        .purchaseItem(item.id);
    if (!mounted) return;

    if (newBalance != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achat confirmé: ${item.name}. Nouveau solde: $newBalance 💡',
          ),
        ),
      );
      return;
    }

    final error = ref.read(shopPurchaseProvider);
    final message = error.whenOrNull(error: (e, _) => e.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Impossible de finaliser cet achat.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopDataAsync = ref.watch(shopDataProvider);
    final purchaseState = ref.watch(shopPurchaseProvider);
    final isPurchasing = purchaseState is AsyncLoading<void>;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: shopDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Impossible de charger la boutique.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  PanarButton(
                    label: 'Réessayer',
                    onPressed: () => ref.invalidate(shopDataProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (shopData) {
          final sectionData = _buildSections(shopData.items);
          final selectedTabKey = _tabs[_selectedTab];
          final selectedSections = sectionData[selectedTabKey] ?? const [];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PanarBreadcrumb('Boutique'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${shopData.balance} 💡',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "T'as trop d'Ampoules ?",
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text("Lâche la moula", style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tabs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final selected = _selectedTab == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _tabs[i],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (selectedSections.isEmpty)
                    Text(
                      'Aucun article Supabase disponible dans cette catégorie.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    ...selectedSections.map((section) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: _ShopSection(
                          title: section.title,
                          isCoins: section.isCoins,
                          items: section.items,
                          isPurchasing: isPurchasing,
                          onBuy: _handlePurchase,
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, List<_ShopSectionData>> _buildSections(
    List<ShopItemEntity> items,
  ) {
    final uncategorized = <ShopItemEntity>[];
    final pansement = items
        .where((item) {
          final isMatch = _matchesCategory(item.category, _pansementKeys);
          if (!isMatch &&
              !_matchesCategory(item.category, _cosmeticKeys) &&
              !_matchesCategory(item.category, _bankKeys)) {
            uncategorized.add(item);
          }
          return isMatch;
        })
        .map((item) => _ShopItem.fromEntity(item))
        .toList();
    final cosmetic = items
        .where((item) => _matchesCategory(item.category, _cosmeticKeys))
        .map((item) => _ShopItem.fromEntity(item))
        .toList();
    final bank = items
        .where((item) => _matchesCategory(item.category, _bankKeys))
        .map((item) => _ShopItem.fromEntity(item))
        .toList();
    pansement.addAll(uncategorized.map((item) => _ShopItem.fromEntity(item)));

    return {
      'Pansement': [_ShopSectionData(title: 'Pansement', items: pansement)],
      'Cosmétiques': [
        _ShopSectionData(title: 'Le tiroir à chaussettes', items: cosmetic),
      ],
      'La banque 💡': [
        _ShopSectionData(title: 'La Banque aux 💡', isCoins: true, items: bank),
      ],
    };
  }

  bool _matchesCategory(String value, Set<String> candidates) {
    final normalized = value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ï', 'i')
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');
    return candidates.any(normalized.contains);
  }
}

class _ShopItem {
  final String id;
  final String name;
  final String subtitle;
  final int? price;

  const _ShopItem({
    required this.id,
    required this.name,
    required this.subtitle,
    this.price,
  });

  factory _ShopItem.fromEntity(ShopItemEntity item) {
    return _ShopItem(
      id: item.id,
      name: item.name,
      subtitle: item.description,
      price: item.pricePetons,
    );
  }
}

class _ShopSection extends StatelessWidget {
  final String title;
  final List<_ShopItem> items;
  final bool isCoins;
  final bool isPurchasing;
  final Future<void> Function(_ShopItem item) onBuy;

  const _ShopSection({
    required this.title,
    required this.items,
    this.isCoins = false,
    required this.isPurchasing,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: isCoins
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleSmall,
                        ),
                        if (item.subtitle.isNotEmpty && !isCoins) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${item.price ?? 0} 💡',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: isPurchasing ? null : () => onBuy(item),
                      child: isPurchasing
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.shopping_basket_outlined,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopSectionData {
  final String title;
  final List<_ShopItem> items;
  final bool isCoins;

  const _ShopSectionData({
    required this.title,
    required this.items,
    this.isCoins = false,
  });
}

const _pansementKeys = {
  'pansement',
  'consumable',
  'consumables',
  'boost',
  'booster',
  'utility',
};
const _cosmeticKeys = {
  'cosmetique',
  'cosmetics',
  'cosmetic',
  'skin',
  'apparel',
  'style',
};
const _bankKeys = {'banque', 'bank', 'coins', 'petons', 'pack', 'currency'};

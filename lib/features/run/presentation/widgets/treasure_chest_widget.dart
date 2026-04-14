import 'package:flutter/material.dart';

/// Widget animé d'un coffre au trésor qui s'ouvre pour révéler les petons gagnés.
class TreasureChestWidget extends StatefulWidget {
  final bool isOpen;
  final int petons;

  const TreasureChestWidget({
    super.key,
    required this.isOpen,
    required this.petons,
  });

  @override
  State<TreasureChestWidget> createState() => _TreasureChestWidgetState();
}

class _TreasureChestWidgetState extends State<TreasureChestWidget>
    with TickerProviderStateMixin {
  late AnimationController _lidController;
  late AnimationController _coinsController;
  late AnimationController _glowController;

  late Animation<double> _lidAngle;
  late Animation<double> _coinsScale;
  late Animation<double> _coinsOpacity;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _lidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _coinsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _lidAngle = Tween<double>(begin: 0, end: -0.7).animate(
      CurvedAnimation(parent: _lidController, curve: Curves.easeOutBack),
    );
    _coinsScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _coinsController, curve: Curves.elasticOut),
    );
    _coinsOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _coinsController, curve: Curves.easeIn));
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(TreasureChestWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _lidController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _coinsController.forward();
      });
    }
  }

  @override
  void dispose() {
    _lidController.dispose();
    _coinsController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final gold = const Color(0xFFFFB800);

    return SizedBox(
      width: 200,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo lumineux quand ouvert
          if (widget.isOpen)
            AnimatedBuilder(
              animation: _glow,
              builder: (_, _) => Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.3 * _glow.value),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

          // Coffre principal
          Positioned(
            bottom: 20,
            child: _ChestBody(isOpen: widget.isOpen, color: primary),
          ),

          // Couvercle animé
          Positioned(
            bottom: 80,
            child: AnimatedBuilder(
              animation: _lidAngle,
              builder: (_, _) => Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_lidAngle.value),
                child: _ChestLid(color: primary),
              ),
            ),
          ),

          // Petons au centre du coffre ouvert
          if (widget.isOpen)
            Positioned(
              bottom: 60,
              child: AnimatedBuilder(
                animation: _coinsController,
                builder: (_, _) => Opacity(
                  opacity: _coinsOpacity.value,
                  child: Transform.scale(
                    scale: _coinsScale.value,
                    child: _PetonsDisplay(petons: widget.petons, gold: gold),
                  ),
                ),
              ),
            ),

          // Particules de pièces
          if (widget.isOpen) ..._buildCoinParticles(gold),
        ],
      ),
    );
  }

  List<Widget> _buildCoinParticles(Color gold) {
    return List.generate(6, (i) {
      final angle = (i * 60.0) * (3.14159 / 180);
      final radius = 70.0;
      return Positioned(
        bottom: 80 + radius * 0.5,
        left: 100 + radius * (i.isEven ? 1 : -1) * 0.4,
        child: AnimatedBuilder(
          animation: _coinsController,
          builder: (_, _) {
            final t = _coinsController.value;
            return Opacity(
              opacity: t > 0.3 ? (1 - ((t - 0.3) / 0.7)).clamp(0, 1) : 0,
              child: Transform.translate(
                offset: Offset(
                  (radius * (i.isEven ? 1 : -1) * t * 0.6),
                  -radius * t * (0.8 + angle * 0.1),
                ),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gold.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '₽',
                      style: TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _ChestBody extends StatelessWidget {
  final bool isOpen;
  final Color color;

  const _ChestBody({required this.isOpen, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Serrure
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          // Bande dorée
          Container(
            width: 100,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChestLid extends StatelessWidget {
  final Color color;

  const _ChestLid({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 100,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB800),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _PetonsDisplay extends StatelessWidget {
  final int petons;
  final Color gold;

  const _PetonsDisplay({required this.petons, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                '+$petons petons',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

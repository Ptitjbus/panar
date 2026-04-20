import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

enum PanarChipVariant { black, gray }

class PanarChip extends StatelessWidget {
  final String label;
  final PanarChipVariant variant;

  const PanarChip(this.label, {super.key, this.variant = PanarChipVariant.gray});

  const PanarChip.black(this.label, {super.key}) : variant = PanarChipVariant.black;

  @override
  Widget build(BuildContext context) {
    final isBlack = variant == PanarChipVariant.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isBlack ? AppColors.chipBlack : AppColors.chipGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isBlack ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

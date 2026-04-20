import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

enum PanarButtonVariant { gray, black }

class PanarButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PanarButtonVariant variant;
  final bool fullWidth;

  const PanarButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PanarButtonVariant.gray,
    this.fullWidth = true,
  });

  const PanarButton.black({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  }) : variant = PanarButtonVariant.black;

  @override
  Widget build(BuildContext context) {
    final isBlack = variant == PanarButtonVariant.black;
    final bg = isBlack ? AppColors.textPrimary : AppColors.surface;
    final fg = isBlack ? Colors.white : AppColors.textPrimary;

    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        decoration: BoxDecoration(
          color: onPressed == null ? AppColors.surfaceDark : bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: onPressed == null ? AppColors.textSecondary : fg,
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

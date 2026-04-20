import 'package:flutter/material.dart';

import 'panar_button.dart';

class PanarWizardFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String continueLabel;

  const PanarWizardFooter({
    super.key,
    this.onBack,
    this.onContinue,
    this.continueLabel = 'Continuer',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Row(
        children: [
          if (onBack != null) ...[
            PanarButton(
              label: '<',
              onPressed: onBack,
              fullWidth: false,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: PanarButton(
              label: continueLabel,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

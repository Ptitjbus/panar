import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class SocialLoginButtons extends ConsumerWidget {
  final VoidCallback? onSuccess;

  const SocialLoginButtons({super.key, this.onSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Column(
      children: [
        // Google Sign In
        OutlinedButton.icon(
          onPressed: authState.isLoading
              ? null
              : () async {
                  final success = await ref
                      .read(authNotifierProvider.notifier)
                      .signInWithGoogle();
                  if (success && onSuccess != null) {
                    onSuccess!();
                  }
                },
          icon: Image.asset(
            'assets/images/google_logo.png',
            height: 24,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.login),
          ),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}

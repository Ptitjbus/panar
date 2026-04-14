import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panar'),
        actions: [
          // Bouton amis
          IconButton(
            icon: const Icon(Icons.people_outlined),
            tooltip: 'Amis',
            onPressed: () {
              context.push(Routes.friends);
            },
          ),
          // Bouton déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(Routes.login);
                }
              }
            },
          ),
        ],
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please log in'));
          }

          return profileAsync.when(
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile not found'));
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      const AnimatedAvatarWidget(
                        isMoving: false,
                        size: 120,
                        showShadow: true,
                      ),

                      const SizedBox(height: 24),

                      // Welcome message
                      Text(
                        'Welcome, ${profile.username}!',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // Email
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 48),

                      // Placeholder content
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Setup Complete!',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your authentication and profile system is working correctly.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (error, stack) =>
                Center(child: Text('Error loading profile: $error')),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

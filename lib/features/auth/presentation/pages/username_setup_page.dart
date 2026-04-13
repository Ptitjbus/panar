import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class UsernameSetupPage extends ConsumerStatefulWidget {
  const UsernameSetupPage({super.key});

  @override
  ConsumerState<UsernameSetupPage> createState() => _UsernameSetupPageState();
}

class _UsernameSetupPageState extends ConsumerState<UsernameSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isCheckingAvailability = false;
  bool? _isAvailable;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability(String username) async {
    if (username.length < 3) {
      setState(() {
        _isAvailable = null;
      });
      return;
    }

    setState(() {
      _isCheckingAvailability = true;
    });

    try {
      final isAvailable = await ref
          .read(profileNotifierProvider.notifier)
          .checkUsernameAvailability(username);

      if (mounted) {
        setState(() {
          _isAvailable = isAvailable;
          _isCheckingAvailability = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAvailability = false;
          _isAvailable = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isAvailable != true) return;

    final username = _usernameController.text.trim();
    final success = await ref
        .read(profileNotifierProvider.notifier)
        .updateUsername(username);

    if (success && mounted) {
      // Also mark onboarding as complete in the database
      await ref.read(profileNotifierProvider.notifier).markOnboardingComplete();

      if (mounted) {
        context.go(Routes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);

    ref.listen<ProfileState>(profileNotifierProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Header
              Text(
                'Choose a Username',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Pick a unique username for your profile',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.person_outline),
                        suffixIcon: _isCheckingAvailability
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _isAvailable == true
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : _isAvailable == false
                            ? const Icon(Icons.error, color: Colors.red)
                            : null,
                        helperText: _isAvailable == false
                            ? 'Username is already taken'
                            : _isAvailable == true
                            ? 'Username is available'
                            : null,
                        helperStyle: TextStyle(
                          color: _isAvailable == false
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      validator: Validators.validateUsername,
                      enabled: !profileState.isLoading,
                      onChanged: (value) {
                        final validation = Validators.validateUsername(value);
                        if (validation == null) {
                          _checkAvailability(value);
                        } else {
                          setState(() {
                            _isAvailable = null;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    CustomButton(
                      onPressed: _isAvailable == true ? _submit : null,
                      isLoading: profileState.isLoading,
                      text: 'Continue',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

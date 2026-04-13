import '../entities/user_entity.dart';

/// Abstract repository for authentication operations
abstract class AuthRepository {
  /// Sign up with email and password
  Future<UserEntity> signUp({required String email, required String password});

  /// Sign in with email and password
  Future<UserEntity> signIn({required String email, required String password});

  /// Sign in with Google
  Future<UserEntity> signInWithGoogle();

  /// Sign out current user
  Future<void> signOut();

  /// Get current authenticated user
  Future<UserEntity?> getCurrentUser();

  /// Send password reset email
  Future<void> resetPassword(String email);

  /// Stream of auth state changes
  Stream<UserEntity?> get authStateChanges;
}

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/user_model.dart';

/// Remote data source for authentication operations using Supabase
class AuthRemoteDataSource {
  final SupabaseClient _supabaseClient;
  GoogleSignIn? _googleSignIn;

  AuthRemoteDataSource(this._supabaseClient);

  /// Get or initialize GoogleSignIn instance
  GoogleSignIn _getGoogleSignIn() {
    if (_googleSignIn != null) return _googleSignIn!;

    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    _googleSignIn = GoogleSignIn(serverClientId: webClientId);
    return _googleSignIn!;
  }

  /// Sign up with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AuthFailure('Failed to create account');
      }

      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('An unexpected error occurred: $e');
    }
  }

  /// Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AuthFailure('Failed to sign in');
      }

      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('An unexpected error occurred: $e');
    }
  }

  /// Sign in with Google
  ///
  /// Note for iOS: The "Skip nonce check" option must be enabled in the
  /// Supabase Google Provider settings due to how the Google iOS SDK
  /// handles nonces natively.
  Future<UserModel> signInWithGoogle() async {
    try {
      // 1. Get the Google Sign-In instance
      final googleSignIn = _getGoogleSignIn();

      // 2. Start the native sign-in flow
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw const AuthFailure('Google sign-in was cancelled');
      }

      // 3. Retrieve tokens
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthFailure('Failed to get Google ID Token');
      }

      // 4. Authenticate with Supabase
      final response = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw const AuthFailure('Failed to sign in with Google');
      }

      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure('An unexpected error occurred: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();

      // Also sign out from Google to allow user to switch accounts next time
      final googleSignIn = _getGoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('An unexpected error occurred: $e');
    }
  }

  /// Get current authenticated user
  Future<UserModel?> getCurrentUser() async {
    final user = _supabaseClient.auth.currentUser;
    return user != null ? UserModel.fromSupabaseUser(user) : null;
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('An unexpected error occurred: $e');
    }
  }

  /// Stream of auth state changes
  Stream<UserModel?> get authStateChanges {
    return _supabaseClient.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      return user != null ? UserModel.fromSupabaseUser(user) : null;
    });
  }
}

/// Provider for AuthRemoteDataSource
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return AuthRemoteDataSource(supabaseClient);
});

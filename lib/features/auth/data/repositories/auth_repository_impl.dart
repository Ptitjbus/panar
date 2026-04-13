import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementation of AuthRepository using AuthRemoteDataSource
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authRemoteDataSource;

  AuthRepositoryImpl(this._authRemoteDataSource);

  @override
  Future<UserEntity> signUp({
    required String email,
    required String password,
  }) async {
    final userModel = await _authRemoteDataSource.signUp(
      email: email,
      password: password,
    );
    return userModel.toEntity();
  }

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final userModel = await _authRemoteDataSource.signIn(
      email: email,
      password: password,
    );
    return userModel.toEntity();
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    final userModel = await _authRemoteDataSource.signInWithGoogle();
    return userModel.toEntity();
  }

  @override
  Future<void> signOut() async {
    await _authRemoteDataSource.signOut();
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final userModel = await _authRemoteDataSource.getCurrentUser();
    return userModel?.toEntity();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _authRemoteDataSource.resetPassword(email);
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return _authRemoteDataSource.authStateChanges.map(
      (userModel) => userModel?.toEntity(),
    );
  }
}

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authRemoteDataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(authRemoteDataSource);
});

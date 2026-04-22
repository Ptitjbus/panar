import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../data/repositories/friends_repository_impl.dart';
import '../../domain/entities/friendship_entity.dart';

/// State class for friends
class FriendsState {
  final List<FriendshipEntity> friends;
  final List<FriendshipEntity> receivedRequests;
  final List<FriendshipEntity> sentRequests;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const FriendsState({
    this.friends = const [],
    this.receivedRequests = const [],
    this.sentRequests = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  FriendsState copyWith({
    List<FriendshipEntity>? friends,
    List<FriendshipEntity>? receivedRequests,
    List<FriendshipEntity>? sentRequests,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      receivedRequests: receivedRequests ?? this.receivedRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Friends state notifier
class FriendsNotifier extends StateNotifier<FriendsState> {
  final Ref _ref;
  final String? _userId;
  StreamSubscription<void>? _realtimeSubscription;

  FriendsNotifier(this._ref, this._userId) : super(const FriendsState()) {
    if (_userId != null && _userId.isNotEmpty) {
      _initialize();
    }
  }

  /// Initialize: load data and setup realtime
  Future<void> _initialize() async {
    await loadFriends();
    _setupRealtimeSubscription();
  }

  /// Load all friends data
  Future<void> loadFriends() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);

      final results = await Future.wait([
        friendsRepository.getMyFriends(),
        friendsRepository.getReceivedRequests(),
        friendsRepository.getSentRequests(),
      ]);

      if (!mounted) return;
      state = state.copyWith(
        friends: results[0],
        receivedRequests: results[1],
        sentRequests: results[2],
        isLoading: false,
      );
    } on DatabaseFailure catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur de connexion. Veuillez réessayer',
      );
    }
  }

  /// Search users by username
  Future<List<ProfileEntity>> searchUsers(String username) async {
    if (username.trim().length < 3) {
      return [];
    }

    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      final authState = _ref.read(authStateProvider);
      final currentUserId = authState.value?.id;

      if (currentUserId == null) {
        return [];
      }

      final allUsers = await friendsRepository.searchUsers(username.trim());

      // Filter out current user, existing friends, and pending requests
      final existingFriendIds = state.friends
          .map((f) => f.getOtherUserId(currentUserId))
          .toSet();
      final pendingRequestIds = <String>{
        ...state.receivedRequests.map((f) => f.requesterId),
        ...state.sentRequests.map((f) => f.addresseeId),
      };

      final filtered = allUsers.where((user) {
        final isSelf = user.id == currentUserId;
        final isExistingFriend = existingFriendIds.contains(user.id);
        final isPending = pendingRequestIds.contains(user.id);

        return !isSelf && !isExistingFriend && !isPending;
      }).toList();

      return filtered;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return [];
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la recherche');
      return [];
    }
  }

  /// Send a friend request
  Future<bool> sendFriendRequest(String addresseeId) async {
    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      await friendsRepository.sendFriendRequest(addresseeId);

      state = state.copyWith(successMessage: 'Demande d\'ami envoyée');

      // Reload to get updated lists
      await loadFriends();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erreur lors de l\'envoi de la demande',
      );
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptRequest(String friendshipId) async {
    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      await friendsRepository.acceptFriendRequest(friendshipId);

      state = state.copyWith(successMessage: 'Demande acceptée');

      // Reload to get updated lists
      await loadFriends();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de l\'acceptation');
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectRequest(String friendshipId) async {
    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      await friendsRepository.rejectFriendRequest(friendshipId);

      state = state.copyWith(successMessage: 'Demande refusée');

      // Reload to get updated lists
      await loadFriends();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du refus');
      return false;
    }
  }

  /// Cancel a sent friend request
  Future<bool> cancelSentRequest(String friendshipId) async {
    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      await friendsRepository.rejectFriendRequest(friendshipId);

      state = state.copyWith(successMessage: 'Demande annulée');

      // Reload to get updated lists
      await loadFriends();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de l\'annulation');
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendshipId) async {
    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      await friendsRepository.removeFriend(friendshipId);

      state = state.copyWith(successMessage: 'Ami supprimé');

      // Reload to get updated lists
      await loadFriends();
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors de la suppression');
      return false;
    }
  }

  /// Setup realtime subscription
  void _setupRealtimeSubscription() {
    try {
      final friendsRepository = _ref.read(friendsRepositoryProvider);
      final authState = _ref.read(authStateProvider);
      final currentUserId = authState.value?.id;

      if (currentUserId == null) return;

      _realtimeSubscription = friendsRepository.watchFriendships().listen(
        (_) {
          // When something changes, reload everything to get full profiles
          loadFriends();
        },
        onError: (error) {
          // Silently handle realtime errors
        },
      );
    } catch (e) {
      // Silently fail realtime setup
    }
  }

  /// Clear messages
  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for friends notifier
final friendsNotifierProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
      final authState = ref.watch(authStateProvider);
      final userId = authState.value?.id;

      return FriendsNotifier(ref, userId);
    });

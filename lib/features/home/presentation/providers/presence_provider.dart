import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

/// Tracks which users are currently online via Supabase Realtime presence.
/// Returns a set of user IDs that are actively on the app.
final onlineUsersProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.read(authStateProvider).value?.id;
  if (userId == null) return Stream.value({});

  final supabase = Supabase.instance.client;
  final channel = supabase.channel('user-presence');
  final controller = StreamController<Set<String>>.broadcast();

  channel
      .onPresenceSync((_) {
        try {
          final presenceList = channel.presenceState();
          final onlineIds = <String>{};
          for (final entry in presenceList) {
            for (final presence in entry.presences) {
              final uid = presence.payload['user_id'] as String?;
              if (uid != null) onlineIds.add(uid);
            }
          }
          if (!controller.isClosed) controller.add(onlineIds);
        } catch (_) {}
      })
      .subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await channel.track({'user_id': userId});
          } catch (_) {}
        }
      });

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

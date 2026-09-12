import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Provider for [AuthService] instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// StreamProvider listening globally to Supabase [AuthState]
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current authenticated user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateStreamProvider);
  return authState.asData?.value.session?.user ?? Supabase.instance.client.auth.currentUser;
});

/// Check if user is logged in
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

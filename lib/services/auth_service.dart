import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  /// Current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Active session
  Session? get currentSession => _client.auth.currentSession;

  /// Global authentication state stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Check if current user email is verified
  bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt != null;
  }

  /// Get formatted user display name
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Student';

    final meta = user.userMetadata;
    final metaName = (meta?['full_name'] ?? meta?['fullName'] ?? meta?['name']) as String?;
    if (metaName != null && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }

    final email = user.email;
    if (email != null && email.contains('@')) {
      final nameFromEmail = email.split('@').first;
      if (nameFromEmail.isNotEmpty) {
        return nameFromEmail[0].toUpperCase() + nameFromEmail.substring(1);
      }
    }

    return 'Student';
  }

  /// Sign up with email, password, and optional full name
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      return response;
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Sign in with passwordless Magic Link
  Future<void> signInWithMagicLink(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: 'academicassistant://login-callback/',
      );
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// OAuth Sign-In (Google, Apple, Github, etc.) with optional scopes and queryParams
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    try {
      final success = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: 'academicassistant://login-callback/',
        scopes: scopes,
        queryParams: queryParams,
      );
      return success;
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Link an additional Google account with offline access & gmail scope
  Future<bool> linkAdditionalGoogleAccount() async {
    return await signInWithOAuth(
      OAuthProvider.google,
      scopes: 'https://www.googleapis.com/auth/gmail.readonly',
      queryParams: {
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );
  }

  /// Save provider refresh token to user_gmail_accounts table if present
  Future<void> saveGmailRefreshToken() async {
    try {
      final session = _client.auth.currentSession;
      if (session?.providerRefreshToken != null && session?.user.id != null) {
        final userId = session!.user.id;
        final refreshToken = session.providerRefreshToken!;
        final googleEmail = session.user.email ?? session.user.userMetadata?['email'] ?? currentUser?.email ?? 'primary@gmail.com';

        await _client.from('user_gmail_accounts').upsert({
          'user_id': userId,
          'google_email': googleEmail,
          'refresh_token': refreshToken,
        }, onConflict: 'user_id,google_email');

        await _client.from('gmail_tokens').upsert({
          'user_id': userId,
          'refresh_token': refreshToken,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error saving gmail refresh token: $e');
    }
  }

  /// Get all linked Gmail accounts for current user
  Future<List<Map<String, dynamic>>> getLinkedGmailAccounts() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    try {
      final res = await _client
          .from('user_gmail_accounts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching linked gmail accounts: $e');
      return [];
    }
  }

  /// Remove a linked Gmail account by ID
  Future<void> removeLinkedGmailAccount(String accountId) async {
    await _client.from('user_gmail_accounts').delete().eq('id', accountId);
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'academicassistant://reset-password/',
      );
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Update user metadata profile (full_name) and public.profiles table
  Future<UserResponse> updateProfile({required String fullName}) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          data: {'full_name': fullName.trim()},
        ),
      );

      final userId = currentUser?.id;
      if (userId != null) {
        try {
          await _client.from('profiles').upsert({
            'id': userId,
            'email': currentUser?.email ?? '',
            'full_name': fullName.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          debugPrint('Profiles table upsert notice: $dbError');
        }
      }

      return response;
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Get user profile data from public.profiles table
  Future<Map<String, dynamic>?> getProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client.from('profiles').select().eq('id', userId).maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Update read_all_emails preference in public.profiles table
  Future<void> updateReadAllEmails(bool readAll) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('profiles').upsert({
      'id': userId,
      'read_all_emails': readAll,
    }, onConflict: 'id');
  }

  /// Get user's custom trusted email filters
  Future<List<Map<String, dynamic>>> getEmailFilters() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    try {
      final res = await _client
          .from('user_email_filters')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching email filters: $e');
      return [];
    }
  }

  /// Add a trusted sender email filter
  Future<void> addEmailFilter(String email) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('user_email_filters').insert({
      'user_id': userId,
      'sender_email': email.trim().toLowerCase(),
    });
  }

  /// Delete a trusted sender email filter by ID
  Future<void> deleteEmailFilter(String filterId) async {
    await _client.from('user_email_filters').delete().eq('id', filterId);
  }

  /// Update password for currently authenticated user
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Update email address for currently authenticated user
  Future<UserResponse> updateEmail(String newEmail) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
      );
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await CacheService().clearAllCache();
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw 'Error signing out. Please try again.';
    }
  }

  /// Securely delete account via Supabase RPC function
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_user_account');
      await signOut();
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  /// Resend email verification email
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } on AuthException catch (e) {
      throw _parseAuthError(e.message);
    } catch (e) {
      throw _handleGenericError(e);
    }
  }

  String _handleGenericError(Object e) {
    final str = e.toString().toLowerCase();
    if (str.contains('failed to fetch') ||
        str.contains('clientexception') ||
        str.contains('err_name_not_resolved') ||
        str.contains('socketexception') ||
        str.contains('failed host lookup')) {
      return 'Unable to connect to Supabase. Please check your network connection or .env configuration.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  String _parseAuthError(String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')) {
      return 'Invalid email or password. Please verify your credentials and try again.';
    } else if (lower.contains('email not confirmed')) {
      return 'Your email address is not verified yet. Please check your inbox for the confirmation link.';
    } else if (lower.contains('user already registered') || lower.contains('already exists')) {
      return 'An account with this email address already exists. Please try logging in.';
    } else if (lower.contains('password should be at least')) {
      return 'Password is too weak. Must be at least 6 characters.';
    } else if (lower.contains('rate limit')) {
      return 'Too many authentication requests. Please wait a moment before trying again.';
    } else if (lower.contains('session expired') || lower.contains('jwt expired')) {
      return 'Your session has expired. Please log in again.';
    }
    return rawError;
  }
}

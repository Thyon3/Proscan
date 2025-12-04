// core/services/auth_service.dart
import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thyscan/core/config/app_env.dart';
import 'package:thyscan/core/errors/failures.dart';
import 'package:thyscan/core/models/app_user.dart';
import 'package:thyscan/core/services/app_logger.dart';

/// Singleton service for handling authentication with Supabase.
/// Supports email/password and Google Sign-In.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool _isInitialized = false;
  SupabaseClient? _supabase;
  final _userController = StreamController<AppUser?>.broadcast();

  /// Gets the Supabase client instance.
  /// Throws [StateError] if not initialized.
  SupabaseClient get supabase {
    if (!_isInitialized || _supabase == null) {
      throw StateError('AuthService not initialized. Call init() first.');
    }
    return _supabase!;
  }

  /// Initializes Supabase with PKCE flow for deep linking support.
  /// Reads SUPABASE_URL and SUPABASE_ANON_KEY from environment or uses defaults.
  Future<void> init() async {
    if (_isInitialized) {
      AppLogger.warning('AuthService already initialized');
      return;
    }

    try {
      // Check if Supabase is already initialized
      if (Supabase.instance.isInitialized) {
        _supabase = Supabase.instance.client;
        AppLogger.info('Using existing Supabase instance');
      } else {
        // Initialize with PKCE flow for deep linking support
        // Credentials are loaded from .env file via envied (compile-time obfuscated)
        final supabaseUrl = AppEnv.supabaseUrl;
        final supabaseAnonKey = AppEnv.supabaseAnonKey;

        if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
          throw AuthFailure(
            'Supabase credentials not found. Please ensure .env file exists with SUPABASE_URL and SUPABASE_ANON_KEY, then run: flutter pub run build_runner build',
          );
        }

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        _supabase = Supabase.instance.client;
        AppLogger.info('Supabase initialized with PKCE flow');
      }

      // Listen to auth state changes and transform to AppUser stream
      supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        AppLogger.info(
          'Auth state changed: ${event.toString()}',
          data: {'hasSession': session != null},
        );

        final user = session?.user;
        if (user != null) {
          final appUser = AppUser.fromSupabase(user);
          _userController.add(appUser);
          AppLogger.info('User authenticated: ${appUser.email}');
        } else {
          _userController.add(null);
          AppLogger.info('User signed out');
        }
      });

      _isInitialized = true;
      AppLogger.info('AuthService initialized successfully');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize AuthService',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Failed to initialize authentication: ${e.toString()}');
    }
  }

  /// Signs up a new user with email and password.
  /// Optionally sets the user's name in metadata.
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    try {
      AppLogger.info('Signing up user with email', data: {'email': email});

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null && name.isNotEmpty
            ? {'name': name, 'full_name': name}
            : null,
      );

      if (response.user == null) {
        throw AuthFailure('Sign up failed: No user returned');
      }

      AppLogger.info(
        'User signed up successfully',
        data: {'userId': response.user!.id},
      );
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error('Sign up failed', error: e, data: {'message': message});
      throw AuthFailure(message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during sign up',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Sign up failed: ${e.toString()}');
    }
  }

  /// Signs in an existing user with email and password.
  Future<void> signInWithEmail(String email, String password) async {
    try {
      AppLogger.info('Signing in user with email', data: {'email': email});

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthFailure('Sign in failed: No user returned');
      }

      AppLogger.info(
        'User signed in successfully',
        data: {'userId': response.user!.id},
      );
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error('Sign in failed', error: e, data: {'message': message});
      throw AuthFailure(message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during sign in',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Sign in failed: ${e.toString()}');
    }
  }

  /// Signs in a user using Google Sign-In (native flow).
  /// Uses the native Google Sign-In SDK to get tokens, then passes them to Supabase.
  Future<void> signInWithGoogle() async {
    try {
      AppLogger.info('Starting Google Sign-In (native flow)');

      // 1. Initialize Google Sign-In with the serverClientId
      // CRITICAL FIX: The serverClientId must be the Web Application Client ID
      // from Google Cloud Console. This is required for iOS to exchange the token.
      final googleSignIn = GoogleSignIn(
        scopes: <String>['email', 'profile'],
        serverClientId: AppEnv.googleWebClientId,
      );

      // Sign in with Google (native flow)
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        throw AuthFailure('Google sign-in was cancelled');
      }

      // Get authentication details
      final googleAuth = await googleUser.authentication;
      // Note: The accessToken is not strictly needed by Supabase's signInWithIdToken,
      // but the ID Token is mandatory. Keeping the check robust.
      if (googleAuth.idToken == null) {
        throw AuthFailure('Failed to get Google ID token');
      }

      AppLogger.info(
        'Google Sign-In successful, exchanging ID token with Supabase',
      );

      // Sign in to Supabase using the Google ID token
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken, // Optional but good to pass
      );

      if (response.user == null) {
        throw AuthFailure('Google sign-in failed: No user returned');
      }

      AppLogger.info(
        'Google Sign-In completed successfully',
        data: {'userId': response.user!.id},
      );
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error(
        'Google sign-in failed',
        error: e,
        data: {'message': message},
      );
      throw AuthFailure(message);
    } catch (e, stack) {
      if (e is AuthFailure) rethrow;
      AppLogger.error(
        'Unexpected error during Google sign-in',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Signs out the current user and clears the session.
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out user');

      await supabase.auth.signOut();

      // Clear any local cache if needed
      // (e.g., clear Hive boxes, shared preferences, etc.)

      AppLogger.info('User signed out successfully');
    } on AuthException catch (e) {
      final message = _mapAuthExceptionToMessage(e);
      AppLogger.error('Sign out failed', error: e, data: {'message': message});
      throw AuthFailure(message);
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during sign out',
        error: e,
        stack: stack,
      );
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }

  /// Stream of the current authenticated user.
  /// Emits `null` when the user is signed out.
  /// The stream is debounced to avoid rapid state changes.
  Stream<AppUser?> get userStream {
    if (!_isInitialized) {
      throw StateError('AuthService not initialized. Call init() first.');
    }

    // Return the current user immediately, then stream updates
    final current = currentUser;
    return Stream<AppUser?>.value(
      current,
    ).asyncExpand((_) => _userController.stream).distinct();
  }

  /// Gets the current authenticated user synchronously.
  /// Returns `null` if no user is signed in.
  AppUser? get currentUser {
    if (!_isInitialized) {
      return null;
    }

    try {
      final session = supabase.auth.currentSession;
      final user = session?.user;
      if (user != null) {
        return AppUser.fromSupabase(user);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting current user', error: e);
      return null;
    }
  }

  /// Maps Supabase [AuthException] to user-friendly error messages.
  String _mapAuthExceptionToMessage(AuthException e) {
    final message = e.message.toLowerCase();

    // Email validation errors
    if (message.contains('invalid email') || message.contains('email format')) {
      return 'Invalid email format';
    }

    // Password errors
    if (message.contains('password') && message.contains('weak')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    if (message.contains('password') && message.contains('wrong')) {
      return 'Wrong password';
    }
    if (message.contains('password') && message.contains('invalid')) {
      return 'Invalid password';
    }

    // User not found
    if (message.contains('user not found') || message.contains('no user')) {
      return 'No account found with this email';
    }

    // Email already exists
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'An account with this email already exists';
    }

    // Network errors
    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Rate limiting
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many requests. Please try again later.';
    }

    // Generic Supabase error - use the original message if it's user-friendly
    if (e.message.isNotEmpty) {
      return e.message;
    }

    // Fallback
    return 'Authentication failed. Please try again.';
  }

  /// Disposes the service and cleans up resources.
  void dispose() {
    _userController.close();
    _isInitialized = false;
  }
}

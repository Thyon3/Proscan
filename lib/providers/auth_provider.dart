// providers/auth_provider.dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:thyscan/core/models/app_user.dart';
import 'package:thyscan/core/services/auth_service.dart';

part 'auth_provider.g.dart';

/// Auth state that includes the current user and loading/error states
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AppUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Riverpod provider that watches the current user from AuthService
@riverpod
Stream<AppUser?> authUserStream(Ref ref) {
  return AuthService.instance.userStream;
}

/// Riverpod controller for managing authentication state and operations
@riverpod
class AuthController extends _$AuthController {
  StreamSubscription<AppUser?>? _userSubscription;

  @override
  AuthState build() {
    // Watch the user stream - it returns AsyncValue, so we need to listen to the actual stream
    ref.listen<AsyncValue<AppUser?>>(
      authUserStreamProvider,
      (previous, next) {
        next.whenData((user) {
          state = state.copyWith(
            user: user,
            isLoading: false,
            error: null,
          );
        });
        next.whenOrNull(
          error: (error, stack) {
            state = state.copyWith(
              isLoading: false,
              error: error.toString(),
            );
          },
        );
      },
    );

    // Also listen to the actual stream for real-time updates
    _userSubscription?.cancel();
    _userSubscription = AuthService.instance.userStream.listen(
      (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.toString(),
        );
      },
    );

    // Get initial user synchronously
    final initialUser = AuthService.instance.currentUser;
    return AuthState(user: initialUser);
  }

  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signInWithEmail(email, password);
      // State will be updated via the stream listener
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('AuthFailure: ', ''),
      );
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signUpWithEmail(email, password, name: name);
      // Auto sign in after signup
      await AuthService.instance.signInWithEmail(email, password);
      // State will be updated via the stream listener
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('AuthFailure: ', ''),
      );
      rethrow;
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signInWithGoogle();
      // State will be updated via the stream listener
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('AuthFailure: ', '');
      // Don't set error if user cancelled
      if (errorMessage.toLowerCase().contains('cancelled')) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await AuthService.instance.signOut();
      // State will be updated via the stream listener
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('AuthFailure: ', ''),
      );
      rethrow;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

}


import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/auth_repository.dart';

// Events
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class SignInWithGoogleRequested extends AuthEvent {}

class SignInWithAppleRequested extends AuthEvent {}

class SignInWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  SignInWithEmailRequested(this.email, this.password);
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  SignUpRequested(this.email, this.password);
}

class SignOutRequested extends AuthEvent {}

class SignUpWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  SignUpWithEmailRequested(this.email, this.password);
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      emit(AuthLoading());
      await emit.forEach(
        authRepository.authStateChanges,
        onData: (User? user) {
          if (user != null) {
            return AuthAuthenticated(user);
          } else {
            return AuthUnauthenticated();
          }
        },
      );
    });

    on<SignInWithGoogleRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final userCredential = await authRepository.signInWithGoogle();
        if (userCredential.user != null) {
          emit(AuthAuthenticated(userCredential.user!));
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<SignInWithAppleRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final userCredential = await authRepository.signInWithApple();
        if (userCredential.user != null) {
          emit(AuthAuthenticated(userCredential.user!));
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<SignInWithEmailRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final userCredential = await authRepository.signInWithEmail(
          event.email,
          event.password,
        );
        if (userCredential.user != null) {
          emit(AuthAuthenticated(userCredential.user!));
        } else {
          emit(AuthError('Failed to sign in'));
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email';
            break;
          case 'wrong-password':
            errorMessage = 'Invalid password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          default:
            errorMessage = e.message ?? 'Authentication failed';
        }

        emit(AuthError(errorMessage));
      } catch (e) {
        emit(AuthError('Authentication failed: ${e.toString()}'));
      }
    });

    on<SignOutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.signOut();

        emit(AuthUnauthenticated());
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<SignUpWithEmailRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final userCredential = await authRepository.signUpWithEmail(
          event.email,
          event.password,
        );
        if (userCredential.user != null) {
          emit(AuthAuthenticated(userCredential.user!));
        } else {
          emit(AuthError('Failed to create account'));
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage =
                'This email is already registered. Please sign in or use a different email.';
            break;
          case 'invalid-email':
            errorMessage = 'Please enter a valid email address';
            break;
          case 'weak-password':
            errorMessage =
                'Password is too weak. Please use at least 6 characters.';
            break;
          case 'operation-not-allowed':
            errorMessage =
                'Email/password accounts are not enabled. Please contact support.';
            break;
          default:
            errorMessage = e.message ?? 'Registration failed';
        }

        emit(AuthError(errorMessage));
      } catch (e) {
        emit(AuthError('Registration failed: ${e.toString()}'));
      }
    });
  }

  @override
  void onChange(Change<AuthState> change) {
    super.onChange(change);
  }
}

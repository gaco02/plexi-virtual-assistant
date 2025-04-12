import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ApiService _apiService;

  AuthRepository(this._apiService) {
    // Log current auth state
    final currentUser = _firebaseAuth.currentUser;
  }

  Future<void> registerUserWithBackend(User user) async {
    try {
      print('🔍 AuthRepository: Registering user with backend: ${user.uid}');
      // First store the token
      final token = await user.getIdToken();
      await _secureStorage.write(key: 'auth_token', value: token);
      print('✅ AuthRepository: Stored auth token for user ${user.uid}');

      // Then try to register with backend
      try {
        print('🔍 AuthRepository: Sending registration data to backend for ${user.uid}');
        final userData = {
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'firebase_uid': user.uid,
        };
        print('💾 AuthRepository: Registration data: $userData');
        
        await _apiService.post('/api/auth/register', userData);
        print('✅ AuthRepository: Successfully registered user with backend: ${user.uid}');
      } catch (e) {
        print('❌ AuthRepository: Failed to register user with backend: $e');
        // We still have the token stored, so the user can use the app
        // even if backend registration fails
      }
    } catch (e) {
      // Don't throw to avoid ChangeNotifier issues
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Ensure we're signed out before starting
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Sign in canceled');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final token = await userCredential.user!.getIdToken();
        await _secureStorage.write(key: 'auth_token', value: token);
        await registerUserWithBackend(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential.user != null) {
      final token = await userCredential.user!.getIdToken();
      await _secureStorage.write(key: 'auth_token', value: token);
    }

    return userCredential;
  }

  // Check if email exists before sign up
  Future<bool> checkEmailExists(String email) async {
    try {
      // This is a workaround to check if an email exists
      // We try to sign in with an invalid password
      // If we get user-not-found, the email doesn't exist
      // If we get wrong-password, the email exists
      try {
        await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: 'invalid-password-for-checking',
        );
        // If we get here, the email exists with this password (very unlikely)
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Email doesn't exist
          return false;
        } else if (e.code == 'wrong-password') {
          // Email exists but wrong password
          return true;
        } else {
          // Other error, assume email might exist

          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }

  // Clear Firebase Auth cache
  Future<void> clearAuthCache() async {
    try {
      // Sign out from Firebase to clear any cached state
      await _firebaseAuth.signOut();

      // Clear any stored tokens
      await _secureStorage.delete(key: 'auth_token');
    } catch (e) {}
  }

  // Sign up with email/password with cache clearing
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      // We'll remove the clearAuthCache call as it might be causing issues
      // await clearAuthCache();

      // First check if the email exists
      final emailExists = await checkEmailExists(email);
      if (emailExists) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.',
        );
      }

      // If email doesn't exist, proceed with creating the account

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        try {
          await registerUserWithBackend(userCredential.user!);
        } catch (e) {
          // We don't rethrow here to avoid the ChangeNotifier issue
          // The user is still created in Firebase, which is the main thing
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // First sign out from Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }

      // Then sign out from Firebase and clear token
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
        _secureStorage.delete(key: 'auth_token'),
      ]);
    } catch (e) {
      throw Exception('Failed to sign out');
    }
  }

  // Get stored token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  // Refresh token
  Future<String?> refreshToken() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      final token = await user.getIdToken(true);
      await _secureStorage.write(key: 'auth_token', value: token);
      return token;
    }
    return null;
  }

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      return user;
    });
  }

  Future<String?> getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      return token;
    }
    throw Exception('No authenticated user');
  }
}

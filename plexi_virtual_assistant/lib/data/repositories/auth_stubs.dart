// This file provides stub implementations for platforms that don't support sign_in_with_apple

// Stub class that mimics the sign_in_with_apple API
class SignInWithApple {
  static Future<AppleIDCredential> getAppleIDCredential({
    required List<Object> scopes,
    String? nonce,
  }) async {
    throw Exception('Sign in with Apple is only available on iOS and macOS');
  }
}

// Stub classes for Apple ID credential
class AppleIDCredential {
  final String? identityToken;
  final String? userIdentifier;
  final String? givenName;
  final String? familyName;

  AppleIDCredential({
    this.identityToken,
    this.userIdentifier,
    this.givenName,
    this.familyName,
  });
}

// Stub for Apple ID authorization scopes
class AppleIDAuthorizationScopes {
  static const email = 'email';
  static const fullName = 'fullName';
}

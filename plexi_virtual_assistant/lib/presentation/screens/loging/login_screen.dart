import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../blocs/auth/auth_bloc.dart';
import '../home/home_screen.dart';
import 'name_welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  // Animation properties
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _messageText =
      "The more we chat, the more I grow - and soon I'll be able to help with even more.";
  String _visibleText = '';
  int _charIndex = 0;
  bool _isTextComplete = false;
  Timer? _textAnimationTimer;

  @override
  void initState() {
    super.initState();

    // Text and fade animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    // Start text animation
    _startTextAnimation();
  }

  void _startTextAnimation() {
    _textAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_charIndex < _messageText.length) {
        if (mounted) {
          setState(() {
            _visibleText = _messageText.substring(0, _charIndex + 1);
            _charIndex++;
          });
        }
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isTextComplete = true;
          });
          _animationController.forward(); // fade in the buttons
        }
      }
    });
  }

  @override
  void dispose() {
    _textAnimationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Navigate to email login screen
  void _showEmailLoginScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EmailLoginScreen(),
      ),
    );
  }

  Widget _buildLoginButton(
      String text, IconData icon, VoidCallback onPressed, bool isProcessing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1CD),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ElevatedButton.icon(
        onPressed: isProcessing ? null : onPressed,
        icon: Icon(icon, color: Colors.black87),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFfd7835),
      // Listen for AuthBloc events
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (mounted) {
            setState(() {
              _isLoading = state is AuthLoading;
            });

            if (state is AuthError) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }

            if (state is AuthAuthenticated) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => const NameWelcomeScreen()),
                (route) => false,
              );
            }
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text message that animates
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _visibleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_isTextComplete)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Image.asset(
                              'assets/images/onboarding/plexi_white_maskot.png',
                              width: 90,
                              height: 90,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Login buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLoginButton(
                        'Continue with Google',
                        Icons.g_mobiledata,
                        () => context
                            .read<AuthBloc>()
                            .add(SignInWithGoogleRequested()),
                        _isLoading,
                      ),
                      _buildLoginButton(
                        'Sign in with Apple',
                        Icons.apple,
                        () => context
                            .read<AuthBloc>()
                            .add(SignInWithAppleRequested()),
                        _isLoading,
                      ),
                      _buildLoginButton(
                        'Sign in with Email',
                        Icons.email,
                        () {
                          if (!_isLoading) {
                            _showEmailLoginScreen(context);
                          }
                        },
                        _isLoading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep the EmailLoginScreen class unchanged
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({Key? key}) : super(key: key);

  @override
  _EmailLoginScreenState createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isCreateMode = false;
  bool isProcessing = false;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    _scaffoldMessengerKey.currentState?.clearSnackBars();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white.withAlpha(77)),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            filled: true,
            fillColor: Colors.white.withAlpha(77),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(77),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(77),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(77),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
    bool isProcessing,
  ) {
    return ElevatedButton.icon(
      icon: isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, color: Colors.white),
      label: Text(
        isProcessing ? '' : text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      onPressed: isProcessing ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(77),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: Colors.white.withAlpha(77),
            width: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (mounted) {
          if (state is AuthLoading) {
            setState(() => isProcessing = true);
          } else {
            setState(() => isProcessing = false);
          }
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else if (state is AuthError) {
            _showErrorMessage(state.message);
          }
        }
      },
      child: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              isCreateMode ? 'Create Account' : 'Sign In',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: SizedBox.expand(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: emailController,
                        label: 'Email',
                        obscureText: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: passwordController,
                        label: 'Password',
                        obscureText: true,
                      ),
                      if (isCreateMode) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: confirmPasswordController,
                          label: 'Confirm Password',
                          obscureText: true,
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildLoginButton(
                        isCreateMode ? 'Create Account' : 'Sign In',
                        isCreateMode ? Icons.person_add : Icons.login,
                        () {
                          if (isProcessing) return;

                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();
                          final confirmPassword =
                              confirmPasswordController.text.trim();

                          if (email.isEmpty) {
                            _showErrorMessage('Please enter your email');
                            return;
                          }
                          if (password.isEmpty) {
                            _showErrorMessage('Please enter your password');
                            return;
                          }
                          if (isCreateMode && password != confirmPassword) {
                            _showErrorMessage('Passwords do not match');
                            return;
                          }

                          setState(() => isProcessing = true);
                          if (isCreateMode) {
                            context
                                .read<AuthBloc>()
                                .add(SignUpWithEmailRequested(email, password));
                          } else {
                            context
                                .read<AuthBloc>()
                                .add(SignInWithEmailRequested(email, password));
                          }
                        },
                        isProcessing,
                      ),
                      const SizedBox(height: 24),
                      // Toggle Sign In / Create
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(77),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isCreateMode
                                  ? 'Already have an account?'
                                  : 'Don\'t have an account?',
                              style: TextStyle(
                                color: Colors.white.withAlpha(77),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  isCreateMode = !isCreateMode;
                                });
                              },
                              child: Text(
                                isCreateMode ? 'Sign In' : 'Create Account',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

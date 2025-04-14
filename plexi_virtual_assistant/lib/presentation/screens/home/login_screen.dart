import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../../blocs/auth/auth_bloc.dart';
import 'home_screen.dart';
import '../../widgets/common/gradient_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Combined full text with newline.
  final String _fullText = "Hi, I'm Plexi\nYour AI Assistant";
  String _displayText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Typing animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Fade in the bottom buttons after text finishes typing
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    // Start typing
    _startTypingAnimation();
  }

  void _startTypingAnimation() {
    int index = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (index < _fullText.length) {
        setState(() {
          _displayText = _fullText.substring(0, index + 1);
        });
        index++;
      } else {
        timer.cancel();
        _animationController.forward(); // fade in the buttons
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _timer?.cancel();
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
    String text,
    IconData icon,
    VoidCallback onPressed,
    bool isProcessing,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ElevatedButton(
          onPressed: isProcessing ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withAlpha(77),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: Colors.white.withAlpha(77),
                width: 1,
              ),
            ),
            minimumSize: const Size(double.infinity, 56),
          ),
          child: isProcessing
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.0,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Listen for AuthBloc events
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
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
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        },
        child: GradientBackground(
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Top Section (typing text + icon)
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 60),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(77),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.assistant,
                                size: 50,
                                color: Color(0xFF1a237e),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              _displayText,
                              style: const TextStyle(
                                fontSize: 40,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Section (buttons)
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                              const SizedBox(height: 16),
                              _buildLoginButton(
                                'Continue with Email',
                                Icons.email_outlined,
                                () => _showEmailLoginScreen(context),
                                _isLoading,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withAlpha(77),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
          body: GradientBackground(
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/app_background.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../data/models/user_preferences.dart';
import 'transaction_details_screen.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class TransactionOnboardingScreen extends StatefulWidget {
  const TransactionOnboardingScreen({super.key});

  @override
  State<TransactionOnboardingScreen> createState() =>
      _TransactionOnboardingScreenState();
}

class _TransactionOnboardingScreenState
    extends State<TransactionOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double? _monthlySalary;
  late List<Widget> _pages;
  final TextEditingController _salaryController = TextEditingController();

  void _nextPage() {
    // Dismiss keyboard when moving to next page
    FocusScope.of(context).unfocus();

    if (_currentPage == 1) {
      // For salary page, try to get the salary from the text field
      final salary = double.tryParse(_salaryController.text);
      if (salary != null) {
        setState(() => _monthlySalary = salary);

        // Save to SharedPreferences
        _saveMonthlySalaryToPrefs(salary);
      } else {
        // Don't proceed if salary is not set
        return;
      }
    }

    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // New method to save monthly salary to SharedPreferences
  Future<void> _saveMonthlySalaryToPrefs(double salary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('monthly_salary', salary);
    } catch (e) {}
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      _WelcomePage(onNext: _nextPage),
      _SalaryInputPage(
        controller: _salaryController,
      ),
      _BudgetingRulePage(
        monthlySalary: _monthlySalary,
        onFinish: () {
          if (_monthlySalary != null) {
            FocusScope.of(context).unfocus();
            context.read<PreferencesBloc>().add(
                  SavePreferences(
                    UserPreferences(monthlySalary: _monthlySalary),
                  ),
                );

            // Save to SharedPreferences when finishing onboarding
            _saveMonthlySalaryToPrefs(_monthlySalary!);
          }
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                // title: const Text('Budget Onboarding',
                //     style: TextStyle(color: Colors.white)),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: _pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus(); // Hide keyboard
                          _pageController.previousPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    else
                      // Empty container to maintain spacing when Back button is not shown
                      Container(),
                    _currentPage == 2
                        ? BlocBuilder<PreferencesBloc, PreferencesState>(
                            builder: (context, state) {
                              return CustomButton(
                                text: 'Get Started',
                                onPressed: state is PreferencesLoading
                                    ? null
                                    : () {
                                        if (_monthlySalary != null) {
                                          final prefs = UserPreferences(
                                            monthlySalary: _monthlySalary,
                                            preferredName:
                                                state is PreferencesLoaded
                                                    ? state.preferences
                                                        .preferredName
                                                    : null,
                                          );
                                          context
                                              .read<PreferencesBloc>()
                                              .add(SavePreferences(prefs));
                                        }
                                      },
                              );
                            },
                          )
                        : CustomButton(
                            text: 'Next',
                            onPressed: _nextPage,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Let’s build a budget that works for you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Image.asset(
            'assets/images/transaction/plexi_transactions_2.png',
            height: 180,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Colors.white70,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Text Plexi like a friend — it’ll handle the rest.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}

class _SalaryInputPage extends StatelessWidget {
  final TextEditingController controller;

  const _SalaryInputPage({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hey! What’s your monthly income? I’ll use it to help plan your budget 💰',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 15),
          CustomTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            hintText: 'Type your monthly take-home💵',
          ),
        ],
      ),
    );
  }
}

class _BudgetingRulePage extends StatelessWidget {
  final VoidCallback onFinish;
  final double? monthlySalary;

  const _BudgetingRulePage({
    required this.onFinish,
    required this.monthlySalary,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PreferencesBloc, PreferencesState>(
      listener: (context, state) {
        if (state is PreferencesLoaded) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TransactionDetailsScreen(),
            ),
          );
        } else if (state is PreferencesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save preferences')),
          );
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Here\'s my favorite\nbudgeting rule —',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildRuleCard(
                '🏠',
                '50% Needs',
                'Essentials like rent, groceries,\nand utilities.',
                const Color(0xFF1A4B8E),
              ),
              const SizedBox(height: 16),
              _buildRuleCard(
                '👜',
                '30% Wants',
                'Fun stuff — dining out,\nshopping, entertainment',
                const Color(0xFF4A2B82),
              ),
              const SizedBox(height: 16),
              _buildRuleCard(
                '💰',
                '20% Savings',
                'For future you — saving,\ninvesting, or paying off debt',
                const Color(0xFF1E5937),
              ),
              const Spacer(),
              const Text(
                'Ready to put it into action?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleCard(
      String emoji, String title, String description, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

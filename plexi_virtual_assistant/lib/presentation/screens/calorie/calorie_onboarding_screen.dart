import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/common/app_background.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../data/models/user_preferences.dart';
import '../../../utils/nutrition_calculator.dart';
import 'calorie_details_screen.dart';

class CalorieOnboardingScreen extends StatefulWidget {
  const CalorieOnboardingScreen({super.key});

  @override
  State<CalorieOnboardingScreen> createState() =>
      _CalorieOnboardingScreenState();
}

class _CalorieOnboardingScreenState extends State<CalorieOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double? _weight;
  double? _height;
  int? _age;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  WeightGoal _weightGoal = WeightGoal.maintain;
  Sex? _sex;
  late List<Widget> _pages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load preferences when dependencies are ready
    context.read<PreferencesBloc>().add(LoadPreferences());
  }

  @override
  void initState() {
    super.initState();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      _WelcomePage(onNext: _nextPage),
      _WeightInputPage(
        key: GlobalKey<_WeightInputPageState>(),
        onWeightSubmitted: (weight) {
          setState(() {
            _weight = weight;
          });
        },
      ),
      _HeightInputPage(
        key: GlobalKey<_HeightInputPageState>(),
        onHeightSubmitted: (height) {
          setState(() {
            _height = height;
          });
        },
      ),
      _AgeInputPage(
        key: GlobalKey<_AgeInputPageState>(),
        onAgeSubmitted: (age) {
          setState(() {
            _age = age;
          });
        },
      ),
      _SexSelectionPage(
        key: GlobalKey<_SexSelectionPageState>(),
        onSexSelected: (sex) {
          setState(() {
            _sex = sex;
          });
        },
      ),
      _ActivityLevelPage(
        key: GlobalKey<_ActivityLevelPageState>(),
        onActivityLevelSelected: (activityLevel) {
          setState(() {
            _activityLevel = activityLevel;
          });
        },
      ),
      _WeightGoalPage(
        key: GlobalKey<_WeightGoalPageState>(),
        onWeightGoalSelected: (weightGoal) {
          setState(() {
            _weightGoal = weightGoal;
          });
          // Calculate and save calorie target when all data is available
          if (_weight != null &&
              _height != null &&
              _age != null &&
              _sex != null) {
            final calorieTarget = _calculateDailyCalorieTarget();
            if (calorieTarget != null) {
              final currentState = context.read<PreferencesBloc>().state;
              if (currentState is PreferencesLoaded) {
                final updatedPrefs = currentState.preferences.copyWith(
                  currentWeight: _weight,
                  height: _height,
                  age: _age,
                  sex: _sex,
                  activityLevel: _activityLevel,
                  weightGoal: weightGoal,
                  dailyCalorieTarget: calorieTarget.round(),
                );
                context
                    .read<PreferencesBloc>()
                    .add(SavePreferences(updatedPrefs));
              }
            }
          }
        },
      ),
      _CalorieTargetPage(
        weight: _weight,
        height: _height,
        age: _age,
        sex: _sex,
        activityLevel: _activityLevel,
        weightGoal: _weightGoal,
        dailyTarget: _calculateDailyCalorieTarget(),
      ),
    ];

    // Listen for page changes
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double? _calculateDailyCalorieTarget() {
    if (_weight == null || _height == null || _age == null || _sex == null) {
      return null;
    }

    // Use the NutritionCalculator to calculate BMR
    final bmr = NutritionCalculator.calculateBMR(
      weight: _weight!,
      height: _height!,
      age: _age!,
      sex: _sex!,
    );

    // Calculate TDEE based on activity level
    final tdee = NutritionCalculator.calculateTDEE(bmr, _activityLevel);

    // Calculate calorie target based on weight goal
    final calorieTarget =
        NutritionCalculator.calculateCalorieTarget(tdee, _weightGoal);

    return calorieTarget;
  }

  void _nextPage() {
    // Dismiss keyboard when moving to next page
    FocusScope.of(context).unfocus();

    // Get current state of the form if it's a form page
    if (_pages[_currentPage] is _WeightInputPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<_WeightInputPageState>)
              .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is _HeightInputPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<_HeightInputPageState>)
              .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is _AgeInputPage) {
      final state = (_pages[_currentPage].key as GlobalKey<_AgeInputPageState>)
          .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is _SexSelectionPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<_SexSelectionPageState>)
              .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is _ActivityLevelPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<_ActivityLevelPageState>)
              .currentState;
      if (state != null) {
        state.submitActivityLevel();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    } else if (_pages[_currentPage] is _WeightGoalPage) {
      final state =
          (_pages[_currentPage].key as GlobalKey<_WeightGoalPageState>)
              .currentState;
      if (state != null) {
        state.submitForm();
        // Navigate after form submission
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    // For pages without form, just move to next page
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update the final page with the latest values before building
    _pages[7] = _CalorieTargetPage(
      weight: _weight,
      height: _height,
      age: _age,
      sex: _sex,
      activityLevel: _activityLevel,
      weightGoal: _weightGoal,
      dailyTarget: _calculateDailyCalorieTarget(),
    );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _pages.length,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
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
                          FocusScope.of(context).unfocus();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    else
                      const SizedBox(width: 80), // Placeholder for alignment
                    const Spacer(),
                    if (_currentPage < _pages.length - 1 && _currentPage != 0)
                      CustomButton(
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

  const _WelcomePage({required this.onNext, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.restaurant_menu,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Track Your Nutrition,\nTransform Your Health',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'We\'ll help you track your calories and maintain a healthy diet based on your personal metrics.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          CustomButton(
            text: 'Next',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _WeightInputPage extends StatefulWidget {
  final Function(double weight) onWeightSubmitted;

  const _WeightInputPage({
    Key? key,
    required this.onWeightSubmitted,
  }) : super(key: key);

  @override
  _WeightInputPageState createState() => _WeightInputPageState();
}

class _WeightInputPageState extends State<_WeightInputPage> {
  double _sliderValue = 70.0; // Default weight in kg

  void submitForm() {
    // Always use the slider value since we removed the text input
    widget.onWeightSubmitted(_sliderValue);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What is your weight?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          // Weight unit (kg)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'kg',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          // Display the slider value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _sliderValue.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.blue.withOpacity(0.3),
              valueIndicatorColor: Colors.blue,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              min: 40,
              max: 200,
              divisions: 160,
              label: _sliderValue.toStringAsFixed(0),
              value: _sliderValue,
              onChanged: (value) {
                setState(() {
                  _sliderValue = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeightInputPage extends StatefulWidget {
  final Function(double height) onHeightSubmitted;

  const _HeightInputPage({
    Key? key,
    required this.onHeightSubmitted,
  }) : super(key: key);

  @override
  _HeightInputPageState createState() => _HeightInputPageState();
}

class _HeightInputPageState extends State<_HeightInputPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _heightController = TextEditingController();
  double _sliderValue = 170.0; // Default height in cm

  void submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final height = double.parse(_heightController.text);
      widget.onHeightSubmitted(height);
    } else {
      widget.onHeightSubmitted(_sliderValue);
    }
  }

  @override
  void initState() {
    super.initState();
    _heightController.text = _sliderValue.toString();
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'What is your height?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            // Height unit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'cm',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            // Display slider value
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.lightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _sliderValue.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.blue.withOpacity(0.3),
                valueIndicatorColor: Colors.blue,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                showValueIndicator: ShowValueIndicator.always,
              ),
              child: Slider(
                min: 120,
                max: 220,
                divisions: 100,
                label: _sliderValue.toStringAsFixed(0),
                value: _sliderValue,
                onChanged: (value) {
                  setState(() {
                    _sliderValue = value;
                    _heightController.text = value.toStringAsFixed(0);
                  });
                },
              ),
            ),
            // Markers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('120', style: TextStyle(color: Colors.white54)),
                  Text('145', style: TextStyle(color: Colors.white54)),
                  Text('170', style: TextStyle(color: Colors.white54)),
                  Text('195', style: TextStyle(color: Colors.white54)),
                  Text('220', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Hidden text form for validation
            Opacity(
              opacity: 0,
              child: TextFormField(
                controller: _heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your height';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- UPDATED AGE PAGE (No "Continue" button) -------------------- //
class _AgeInputPage extends StatefulWidget {
  final Function(int age) onAgeSubmitted;

  const _AgeInputPage({
    Key? key,
    required this.onAgeSubmitted,
  }) : super(key: key);

  @override
  _AgeInputPageState createState() => _AgeInputPageState();
}

class _AgeInputPageState extends State<_AgeInputPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();

  /// Validate and submit the form. The parent screen calls this when the user taps "Next."
  void submitForm() {
    // Manual validation since CustomTextField doesn't support validator
    if (_ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your age')),
      );
      return;
    }

    try {
      final age = int.parse(_ageController.text.trim());
      if (age <= 0 || age > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid age (1-120)')),
        );
        return;
      }
      widget.onAgeSubmitted(age);
    } catch (e) {
      // Handle parsing error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number')),
      );
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'What\'s your age?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            // Age input field (visible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomTextField(
                hintText: 'Age',
                controller: _ageController,
                keyboardType: TextInputType.number,
                fillColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 8),
            // Any additional instructions or spacing can go here
          ],
        ),
      ),
    );
  }
}
// ------------------------------------------------------------------------------- //

/// Choose gender
class _SexSelectionPage extends StatefulWidget {
  final Function(Sex) onSexSelected;

  const _SexSelectionPage({
    Key? key,
    required this.onSexSelected,
  }) : super(key: key);

  @override
  State<_SexSelectionPage> createState() => _SexSelectionPageState();
}

class _SexSelectionPageState extends State<_SexSelectionPage> {
  Sex? _selectedSex;

  void submitForm() {
    if (_selectedSex != null) {
      widget.onSexSelected(_selectedSex!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What is your gender',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select your gender to help us calculate your daily calorie needs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGenderOption(
                Sex.female,
                'Female',
                isSelected: _selectedSex == Sex.female,
              ),
              const SizedBox(width: 16),
              _buildGenderOption(
                Sex.male,
                'Male',
                isSelected: _selectedSex == Sex.male,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPreferNotToSayOption(
            isSelected: _selectedSex == Sex.other,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGenderOption(Sex sex, String label, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSex = sex;
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              sex == Sex.female ? Icons.female : Icons.male,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferNotToSayOption({required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSex = Sex.other;
        });
      },
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: const Center(
          child: Text(
            'Prefer not to say',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityLevelPage extends StatefulWidget {
  final Function(ActivityLevel) onActivityLevelSelected;

  const _ActivityLevelPage({
    Key? key,
    required this.onActivityLevelSelected,
  }) : super(key: key);

  @override
  State<_ActivityLevelPage> createState() => _ActivityLevelPageState();
}

class _ActivityLevelPageState extends State<_ActivityLevelPage> {
  ActivityLevel _selectedLevel = ActivityLevel.moderatelyActive;

  /// The parent can call this when the user taps "Next" to finalize selection.
  void submitActivityLevel() {
    widget.onActivityLevelSelected(_selectedLevel);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Prevents bottom overflow by making the content scrollable.
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your activity level',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select your typical activity level to help us calculate your daily calorie needs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                _buildActivityOption(
                  ActivityLevel.sedentary,
                  'Sedentary',
                  'Little or no exercise',
                ),
                _buildActivityOption(
                  ActivityLevel.lightlyActive,
                  'Lightly active',
                  'Light exercise 1-3 days/week',
                ),
                _buildActivityOption(
                  ActivityLevel.moderatelyActive,
                  'Moderately active',
                  'Moderate exercise 3-5 days/week',
                ),
                _buildActivityOption(
                  ActivityLevel.veryActive,
                  'Very active',
                  'Hard exercise 6-7 days/week',
                ),
                _buildActivityOption(
                  ActivityLevel.extraActive,
                  'Extra active',
                  'Very hard exercise & physical job',
                ),
              ],
            ),
            const SizedBox(height: 32),
            // No "Continue" button here.
            // We rely on the parent's Next button, which calls submitActivityLevel().
          ],
        ),
      ),
    );
  }

  Widget _buildActivityOption(
    ActivityLevel level,
    String title,
    String description,
  ) {
    final isSelected = _selectedLevel == level;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedLevel = level;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Radio<ActivityLevel>(
                value: level,
                groupValue: _selectedLevel,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLevel = value;
                    });
                  }
                },
                activeColor: Colors.blue,
                fillColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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

class _WeightGoalPage extends StatefulWidget {
  final Function(WeightGoal) onWeightGoalSelected;

  const _WeightGoalPage({
    Key? key,
    required this.onWeightGoalSelected,
  }) : super(key: key);

  @override
  State<_WeightGoalPage> createState() => _WeightGoalPageState();
}

class _WeightGoalPageState extends State<_WeightGoalPage> {
  WeightGoal? _selectedGoal;

  void submitForm() {
    if (_selectedGoal != null) {
      widget.onWeightGoalSelected(_selectedGoal!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What goal do you have in mind?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          const Text(
            'This will help us calculate your optimal calorie and macronutrient targets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          _buildGoalOption(
            WeightGoal.lose,
            'Lose Weight',
            'Create a calorie deficit to lose weight',
            Icons.trending_down,
          ),
          _buildGoalOption(
            WeightGoal.maintain,
            'Maintain Weight',
            'Stay at your current weight',
            Icons.trending_flat,
          ),
          _buildGoalOption(
            WeightGoal.gain,
            'Gain Weight',
            'Create a calorie surplus to gain weight',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOption(
    WeightGoal goal,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedGoal == goal;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = goal;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieTargetPage extends StatelessWidget {
  final double? weight;
  final double? height;
  final int? age;
  final Sex? sex;
  final ActivityLevel? activityLevel;
  final WeightGoal? weightGoal;
  final double? dailyTarget;

  const _CalorieTargetPage({
    Key? key,
    required this.weight,
    required this.height,
    required this.age,
    required this.sex,
    required this.activityLevel,
    required this.weightGoal,
    required this.dailyTarget,
  }) : super(key: key);

  String _formatCalories() {
    if (dailyTarget == null) return '0';
    return dailyTarget!.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PreferencesBloc, PreferencesState>(
      listener: (context, state) {
        if (state is PreferencesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save preferences')),
          );
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Here\'s your daily nutritional goal',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This can help us calculate your optimal daily calorie needs based on your metrics.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Calorie target display
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 12,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.green),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              _formatCalories(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'calories/day',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Example macronutrient breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMacronutrientCircle(
                            'Protein', '25%', Colors.orange),
                        _buildMacronutrientCircle('Carbs', '50%', Colors.blue),
                        _buildMacronutrientCircle('Fat', '25%', Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.yellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: Colors.yellow,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (weight != null &&
                      height != null &&
                      age != null &&
                      sex != null &&
                      activityLevel != null &&
                      weightGoal != null) {
                    final currentState = context.read<PreferencesBloc>().state;
                    if (currentState is PreferencesLoaded) {
                      final updatedPrefs = currentState.preferences.copyWith(
                        currentWeight: weight,
                        height: height,
                        age: age,
                        sex: sex,
                        activityLevel: activityLevel,
                        weightGoal: weightGoal,
                        dailyCalorieTarget: dailyTarget?.round(),
                      );
                      context
                          .read<PreferencesBloc>()
                          .add(SavePreferences(updatedPrefs));

                      // Navigate only when user clicks Start
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CalorieDetailsScreen(),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please complete all steps before continuing'),
                      ),
                    );
                  }
                },
                label: const Text('Start'),
                icon: const Icon(Icons.arrow_forward),
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMacronutrientCircle(
      String label, String percentage, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: Text(
              percentage,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/api_service.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/restaurant_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/transactions/transaction_repository_new.dart';
import 'data/repositories/calorie_repository.dart';
import 'data/repositories/transactions/transaction_api_service.dart';
import 'data/repositories/transactions/transaction_cache.dart';
import 'data/repositories/preferences_repository.dart';
import 'data/repositories/budget_repository.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/transaction/transaction_bloc.dart';
import 'blocs/calorie/calorie_bloc.dart';
import 'blocs/preferences/preferences_bloc.dart';
import 'blocs/budget/budget_bloc.dart';
import 'blocs/restaurant/restaurant_bloc.dart';
import 'blocs/transaction_analysis/transaction_analysis_bloc.dart';
import 'blocs/budget/budget_event.dart';
import 'blocs/transaction/transaction_event.dart';
import 'blocs/calorie/calorie_event.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/home/login_screen.dart';
import 'presentation/screens/home/onboarding_screen.dart';
import 'data/cache/cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable more verbose logging
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Initialize the CacheManager as early as possible
  final cacheManager = CacheManager();
  await cacheManager.init();
  print('✅ Initialized CacheManager at app startup');

  // Create a single instance of ApiService to be shared across repositories.
  final apiService = ApiService(
      // baseUrl: 'https://tiktok-analyzer-291212790768.us-west1.run.app');
      baseUrl: 'http://192.168.1.213:8000');

  // Create CalorieRepository with ApiService
  final calorieRepository = CalorieRepository(apiService: apiService);

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  runApp(MyApp(
      navigatorKey: navigatorKey,
      apiService: apiService,
      calorieRepository: calorieRepository));
}

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final ApiService apiService;
  final CalorieRepository calorieRepository;

  const MyApp(
      {Key? key,
      required this.navigatorKey,
      required this.apiService,
      required this.calorieRepository})
      : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force UI refresh when app is resumed
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Instantiate your repositories using the single ApiService instance.
    final chatRepository = ChatRepository(widget.apiService);
    final restaurantRepository = RestaurantRepository(widget.apiService);
    final authRepository = AuthRepository(widget.apiService);

    // Create instances of the transaction services with the new modular structure
    final transactionApiService = TransactionApiService(widget.apiService);
    final transactionCache = TransactionCache();
    final transactionRepository =
        TransactionRepository(transactionApiService, transactionCache);

    final preferencesRepository = PreferencesRepository(widget.apiService);
    final budgetRepository = BudgetRepository(widget.apiService);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiService>.value(value: widget.apiService),
        RepositoryProvider<ChatRepository>.value(value: chatRepository),
        RepositoryProvider<RestaurantRepository>.value(
            value: restaurantRepository),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<TransactionRepository>.value(
            value: transactionRepository),
        RepositoryProvider<CalorieRepository>.value(
            value: widget.calorieRepository),
        RepositoryProvider<PreferencesRepository>.value(
            value: preferencesRepository),
        RepositoryProvider<BudgetRepository>.value(value: budgetRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          // 1. Core blocs that don't depend on others
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: authRepository,
            )..add(AuthCheckRequested()),
          ),
          BlocProvider<PreferencesBloc>(
            create: (context) =>
                PreferencesBloc(preferencesRepository)..add(LoadPreferences()),
          ),

          // 2. Feature blocs
          BlocProvider<TransactionAnalysisBloc>(
            create: (context) => TransactionAnalysisBloc(
              repository: transactionRepository,
            ),
          ),
          BlocProvider<TransactionBloc>(
            create: (context) => TransactionBloc(
              repository: transactionRepository,
              analysisBloc: context.read<TransactionAnalysisBloc>(),
            )..add(const LoadDailyTransactions()),
          ),
          BlocProvider<CalorieBloc>(
            create: (context) => CalorieBloc(
              repository: widget.calorieRepository,
              userPreferencesRepository: preferencesRepository,
            )..add(LoadDailyCalories()),
          ),
          BlocProvider<RestaurantBloc>(
            create: (context) => RestaurantBloc(
              restaurantRepository: restaurantRepository,
            ),
          ),

          // 3. ChatBloc that depends on other blocs
          BlocProvider<ChatBloc>(
            create: (context) => ChatBloc(
              chatRepository: chatRepository,
              restaurantRepository: restaurantRepository,
              transactionBloc: context.read<TransactionBloc>(),
              calorieBloc: context.read<CalorieBloc>(),
              authBloc: context.read<AuthBloc>(),
            ),
          ),

          // 4. BudgetBloc that depends on ChatBloc
          BlocProvider<BudgetBloc>(
            create: (context) => BudgetBloc(
              budgetRepository,
              context.read<ChatBloc>(),
              context.read<TransactionBloc>(),
            )..add(LoadTodaysBudget()),
          ),
        ],
        child: MaterialApp(
          title: 'Plexi Chat',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Use home instead of routes and initialRoute
          home: _buildInitialScreen(context),
          navigatorKey: widget.navigatorKey,
          navigatorObservers: [routeObserver],
        ),
      ),
    );
  }

  // Helper method to determine the initial screen based on auth state
  Widget _buildInitialScreen(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthAuthenticated) {
          return BlocBuilder<PreferencesBloc, PreferencesState>(
            builder: (context, prefsState) {
              if (prefsState is PreferencesLoaded) {
                ;
              }

              if (prefsState is! PreferencesLoaded ||
                  prefsState.preferences.preferredName == null ||
                  prefsState.preferences.preferredName!.isEmpty) {
                return const OnboardingScreen();
              }

              return const HomeScreen();
            },
          );
        }
        if (authState is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LoginScreen();
      },
    );
  }
}

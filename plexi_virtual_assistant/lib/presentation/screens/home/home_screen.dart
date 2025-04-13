import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/preferences/preferences_bloc.dart';
import '../../../blocs/transaction/transaction_bloc.dart';
import '../../../blocs/transaction/transaction_event.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../data/repositories/transactions/transaction_repository_new.dart';
import '../../widgets/calorie/calorie_summary.dart';
import '../../widgets/transaction/spending_summary.dart';
import 'settings_screen.dart';
import '../chat_screen.dart';
import 'login_screen.dart';
import '../../widgets/common/app_background.dart';
import '../../../data/models/user_preferences.dart';

// Create a route observer to detect when we return to this screen
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  @override
  void initState() {
    super.initState();
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Hide keyboard on home screen load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      FocusScope.of(context).unfocus();

      // Load transactions when the screen initializes
      _loadTransactionData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to route changes
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);

    // Load data on first dependency change
    if (!_hasLoadedInitialData) {
      _loadTransactionData();
      _hasLoadedInitialData = true;
    }
  }

  @override
  void dispose() {
    // Unregister from lifecycle events
    WidgetsBinding.instance.removeObserver(this);
    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // This is called when we return to this screen (pop back to it)
    super.didPopNext();
    _loadTransactionData();
    // We don't need to force reload calorie data as it's now cached properly
  }

  // Flag to track if we've already loaded data
  bool _hasLoadedInitialData = false;

  // Helper method to load transaction data
  void _loadTransactionData() {
    final transactionBloc = context.read<TransactionBloc>();

    // Force invalidate transaction caches before loading data
    try {
      final transactionRepository = context.read<TransactionRepository>();
      transactionRepository.invalidateTransactionCaches();
    } catch (e) {
      // Ignore
    }

    // Load transaction data with forceRefresh flag
    transactionBloc.add(
        const LoadDailyTransactions(isForWidget: true, forceRefresh: true));
    transactionBloc.add(
        const LoadMonthlyTransactions(isForWidget: true, forceRefresh: true));

    // Only request transaction analysis if needed, don't force refresh
    try {
      final analysisBloc = context.read<TransactionAnalysisBloc>();

      // Check if we already have cached analysis data
      if (analysisBloc.cachedAnalysis == null) {
        analysisBloc.add(const LoadTransactionAnalysis(forceRefresh: false));
      } else {}
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        userPreferencesFuture: context
                                .read<PreferencesBloc>()
                                .state is PreferencesLoaded
                            ? Future.value((context
                                    .read<PreferencesBloc>()
                                    .state as PreferencesLoaded)
                                .preferences)
                            : Future.value(UserPreferences()),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: SizedBox.expand(
            child: AppBackground(
              child: Stack(
                children: [
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<PreferencesBloc, PreferencesState>(
                            builder: (context, state) {
                              final name = state is PreferencesLoaded
                                  ? state.preferences.preferredName ?? 'there'
                                  : 'there';
                              return Text(
                                "Hello $name!",
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),
                          // display tools
                          SpendingSummary(),
                          const SizedBox(height: 5),
                          const CalorieSummary(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(),
                          ),
                        );
                      },
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_state.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../data/models/transaction_analysis.dart';
import '../../../utils/formatting_utils.dart';
import '../common/transparent_card.dart';
import 'budget_needs_graph.dart';

class TransactionAnalysisWidget extends StatefulWidget {
  final TransactionAnalysis? analysis;

  const TransactionAnalysisWidget({
    super.key,
    this.analysis,
  });

  @override
  State<TransactionAnalysisWidget> createState() =>
      _TransactionAnalysisWidgetState();
}

class _TransactionAnalysisWidgetState extends State<TransactionAnalysisWidget>
    with AutomaticKeepAliveClientMixin {
  bool _isFirstBuild = true;

  // Cache the last loaded analysis
  TransactionAnalysis? _cachedAnalysis;

  // Track when the last refresh occurred
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();

    // If we received analysis via constructor, use it
    if (widget.analysis != null) {
      _cachedAnalysis = widget.analysis;
    }

    // Explicitly request analysis data when widget initializes, but only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only request data if we don't already have cached data
      if (_cachedAnalysis == null) {
        context
            .read<TransactionAnalysisBloc>()
            .add(const LoadTransactionAnalysis());
      } else {}
    });
  }

  @override
  void didUpdateWidget(TransactionAnalysisWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update cached analysis if we receive a new one via props
    if (widget.analysis != null && widget.analysis != _cachedAnalysis) {
      setState(() {
        _cachedAnalysis = widget.analysis;
      });
    }
  }

  @override
  bool get wantKeepAlive => true; // Keep the state alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return BlocBuilder<TransactionAnalysisBloc, TransactionAnalysisState>(
      buildWhen: (previous, current) {
        // Only rebuild on state changes that are relevant to analysis
        if (_isFirstBuild) {
          _isFirstBuild = false;

          return true;
        }

        // Don't rebuild if the previous and current states are the same type
        // This prevents unnecessary rebuilds when navigating between screens
        if (previous.runtimeType == current.runtimeType) {
          // Special case for TransactionAnalysisLoaded - check if the analysis data changed
          if (current is TransactionAnalysisLoaded &&
              previous is TransactionAnalysisLoaded) {
            final prevAnalysis = previous.analysis;
            final currAnalysis = current.analysis;
            // Only rebuild if the analysis data actually changed
            final shouldRebuild = prevAnalysis != currAnalysis;

            return shouldRebuild;
          }

          // Special case for TransactionCombinedState - check if the analysis data changed
          if (current is TransactionCombinedState &&
              previous is TransactionCombinedState) {
            final prevState = previous;
            final currState = current;

            // Only rebuild if the analysis data or refresh state changed
            final analysisChanged = prevState.analysis != currState.analysis;
            final refreshStateChanged =
                prevState.isRefreshing != currState.isRefreshing;
            final errorChanged =
                prevState.errorMessage != currState.errorMessage;

            final shouldRebuild =
                analysisChanged || refreshStateChanged || errorChanged;

            return shouldRebuild;
          }

          return false;
        }

        final shouldRebuild = current is TransactionAnalysisLoaded ||
            current is TransactionAnalysisLoading ||
            current is TransactionAnalysisError ||
            current is TransactionCombinedState;

        return shouldRebuild;
      },
      builder: (context, state) {
        // Handle combined state
        if (state is TransactionCombinedState) {
          if (state.analysis != null) {
            _cachedAnalysis = state.analysis; // Cache the analysis

            // If we're refreshing, show a loading indicator
            if (state.isRefreshing) {
              return Stack(
                children: [
                  _buildAnalysisContent(state.analysis!),
                  const Positioned(
                    top: 16,
                    right: 16,
                    child: CircularProgressIndicator(),
                  ),
                ],
              );
            }

            // If there's an error message, show it
            if (state.errorMessage != null) {
              return Stack(
                children: [
                  _buildAnalysisContent(state.analysis!),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(77),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            }

            return _buildAnalysisContent(state.analysis!);
          } else if (_cachedAnalysis != null) {
            // Show cached data if available

            return _buildAnalysisContent(_cachedAnalysis!);
          } else {
            // Show loading if no data available

            return const Center(child: CircularProgressIndicator());
          }
        }

        // Handle regular states
        if (state is TransactionAnalysisLoaded) {
          _cachedAnalysis = state.analysis; // Cache the analysis
          _lastRefreshTime = DateTime.now(); // Update last refresh time

          return _buildAnalysisContent(state.analysis);
        }

        // Show loading indicator with cached data if available
        if (state is TransactionAnalysisLoading && _cachedAnalysis != null) {
          return Stack(
            children: [
              _buildAnalysisContent(_cachedAnalysis!),
              const Positioned(
                top: 16,
                right: 16,
                child: CircularProgressIndicator(),
              ),
            ],
          );
        }

        if (state is TransactionAnalysisLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is TransactionAnalysisError) {
          // If we have cached data, show it with an error message
          if (_cachedAnalysis != null) {
            return Stack(
              children: [
                _buildAnalysisContent(_cachedAnalysis!),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(77),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error refreshing: ${state.message}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            );
          }
          return Center(
              child: Text('Error: ${state.message}',
                  style: const TextStyle(color: Colors.white)));
        }

        // If we have cached data but no specific state, show the cached data
        if (_cachedAnalysis != null) {
          return _buildAnalysisContent(_cachedAnalysis!);
        }

        // Show a button to manually load data if we have no data
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No budget analysis data available',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context
                      .read<TransactionAnalysisBloc>()
                      .add(const LoadTransactionAnalysis());
                },
                child: const Text('Load Budget Analysis'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalysisContent(TransactionAnalysis analysis) {
    // Format the last refresh time if available
    String lastRefreshText = '';
    if (_lastRefreshTime != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastRefreshTime!);

      if (difference.inMinutes < 1) {
        lastRefreshText = 'Updated just now';
      } else if (difference.inHours < 1) {
        lastRefreshText = 'Updated ${difference.inMinutes} min ago';
      } else if (difference.inDays < 1) {
        lastRefreshText = 'Updated ${difference.inHours} hr ago';
      } else {
        lastRefreshText = 'Updated ${difference.inDays} days ago';
      }
    }

    // Debug recommendations
    if (analysis.recommendations.isNotEmpty) {
      for (var recommendation in analysis.recommendations) {}
    }

    return TransparentCard(
      margin: const EdgeInsets.all(8),
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (lastRefreshText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        lastRefreshText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: () {
                      // Trigger manual refresh

                      context
                          .read<TransactionAnalysisBloc>()
                          .add(const ManualRefreshAnalysis());

                      // Update last refresh time
                      setState(() {
                        _lastRefreshTime = DateTime.now();
                      });
                    },
                    tooltip: 'Refresh Analysis',
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          BudgetGraphWidget(
            actual: analysis.actual,
            ideal: analysis.ideal,
          ),
          if (analysis.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            ...analysis.recommendations.map((recommendation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildRecommendationCard(recommendation, context),
              );
            }).toList(),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              'No recommendations available',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
      TransactionRecommendation recommendation, BuildContext context) {
    Color cardColor;
    IconData iconData;

    switch (recommendation.type) {
      case 'reduce_spending':
        cardColor = Colors.red;
        iconData = Icons.trending_down;
        break;
      case 'increase_savings':
        cardColor = Colors.green;
        iconData = Icons.savings;
        break;
      default:
        cardColor = Colors.blue;
        iconData = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor.withAlpha(77),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardColor.withAlpha(77), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withAlpha(77),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(iconData, color: cardColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.message,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.suggestedAction,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (recommendation.potentialSavings > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor.withAlpha(77),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Potential savings: ${FormattingUtils.formatCurrency(recommendation.potentialSavings)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

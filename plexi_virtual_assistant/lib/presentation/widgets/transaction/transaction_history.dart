import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_bloc.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_state.dart';
import '../../../blocs/transaction_analysis/transaction_analysis_event.dart';
import '../../../data/models/transaction.dart';
import '../common/transparent_card.dart';
import '../../../utils/formatting_utils.dart';

class TransactionHistory extends StatefulWidget {
  final String? period;

  const TransactionHistory({Key? key, this.period}) : super(key: key);

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory>
    with AutomaticKeepAliveClientMixin {
  // Selected date for filtering
  DateTime _selectedDate = DateTime.now();
  // Selected category filter (null means "All")
  TransactionCategory? _selectedCategory;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initial data load
    _refreshData(forceRefresh: true);
  }

  /// Refreshes transaction data from the Bloc.
  void _refreshData({bool forceRefresh = false}) {
    context.read<TransactionAnalysisBloc>().add(
          LoadTransactionHistory(
            period: widget.period,
            date: DateFormat('yyyy-MM-dd').format(_selectedDate),
            forceRefresh: forceRefresh,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<TransactionAnalysisBloc, TransactionAnalysisState>(
      listener: (context, state) {
        // If we receive a TransactionAnalysisInitial state, it means we need to refresh
        if (state is TransactionAnalysisInitial) {
          _refreshData(forceRefresh: true);
        }
      },
      builder: (context, state) {
        // Handle loading state
        if (state is TransactionHistoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (state is TransactionHistoryError) {
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle loaded state
        Map<String, List<Transaction>> transactionsByDate = {};

        if (state is TransactionHistoryLoaded) {
          transactionsByDate = state.transactionsByDate;
        } else if (state is TransactionCombinedState &&
            state.transactionsByDate != null) {
          transactionsByDate = state.transactionsByDate!;
        }

        // Flatten transactions from the map into a single list
        final transactions =
            transactionsByDate.values.expand((list) => list).toList();

        if (transactions.isEmpty) {
          return const Center(
            child: Text(
              'No transactions for this time period',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return _buildHistoryContent(transactions);
      },
    );
  }

  /// Builds the history content with the given transactions
  Widget _buildHistoryContent(List<Transaction> transactions) {
    // Filter transactions for the selected date
    final filteredByDate = transactions.where((tx) {
      return tx.timestamp.year == _selectedDate.year &&
          tx.timestamp.month == _selectedDate.month &&
          tx.timestamp.day == _selectedDate.day;
    }).toList();

    // Further filter by category if one is selected
    final filteredTransactions = _selectedCategory == null
        ? filteredByDate
        : filteredByDate
            .where((tx) => tx.category == _selectedCategory)
            .toList();

    // Sort transactions (most recent first)
    filteredTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return SafeArea(
      child: Column(
        children: [
          // Date selector
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DateSelector(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
                _refreshData();
              },
            ),
          ),

          // Category selector
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TransactionCategorySelector(
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
          ),

          // Daily summary for selected date
          if (filteredByDate.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _buildDailySummary(filteredByDate),
            ),

          // Transaction entries list
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No transactions for this date',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      return _buildTransactionCard(transaction);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds a daily summary card showing total spent for the selected date
  Widget _buildDailySummary(List<Transaction> transactions) {
    // Calculate total spent for the day
    final totalSpent = transactions.fold(0.0, (sum, tx) => sum + tx.amount);

    // Count transactions
    final transactionCount = transactions.length;

    // Get most expensive transaction
    transactions.sort((a, b) => b.amount.compareTo(a.amount));
    final mostExpensive = transactions.isNotEmpty ? transactions.first : null;

    return TransparentCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(_selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Spent',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    FormattingUtils.formatCurrency(totalSpent),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$transactionCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (mostExpensive != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  FormattingUtils.getCategoryEmoji(mostExpensive.category),
                  style: TextStyle(
                    fontSize: 16,
                    color: FormattingUtils.getCategoryColor(
                        mostExpensive.category),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Largest expense:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mostExpensive.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  FormattingUtils.formatCurrency(mostExpensive.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the card UI for a single transaction.
  Widget _buildTransactionCard(Transaction transaction) {
    final categoryColor =
        FormattingUtils.getCategoryColor(transaction.category);

    return TransparentCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category icon with background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: categoryColor.withAlpha(77),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                FormattingUtils.getCategoryEmoji(transaction.category),
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Transaction description and amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        transaction.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_money,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          FormattingUtils.formatCurrency(transaction.amount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Category and date pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildInfoPill(
                        transaction.category.displayName,
                        categoryColor,
                        Icons.category,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Options menu
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white70,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showTransactionOptions(transaction),
          ),
        ],
      ),
    );
  }

  /// Builds an info pill similar to the nutrient pills in FoodItemCard
  Widget _buildInfoPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withAlpha(77),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows options for a transaction (view details, edit, delete)
  void _showTransactionOptions(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.white),
                title: const Text('View Details',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement view details functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit Transaction',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editTransaction(transaction);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Transaction',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteTransaction(transaction);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Delete a transaction
  void _deleteTransaction(Transaction transaction) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete "${transaction.description}" (${FormattingUtils.formatCurrency(transaction.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Dispatch delete transaction event to the bloc
              context.read<TransactionAnalysisBloc>().add(
                    DeleteTransactionEvent(transactionId: transaction.id),
                  );
              // Show a snackbar to indicate the transaction is being deleted
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Deleting transaction: ${transaction.description}'),
                  duration: const Duration(seconds: 2),
                ),
              );
              // Refresh data after a short delay to ensure the backend has processed the deletion
              Future.delayed(const Duration(milliseconds: 500), _refreshData);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Edit a transaction
  void _editTransaction(Transaction transaction) {
    // Controllers for the form fields
    final amountController = TextEditingController(
        text: FormattingUtils.formatCurrency(transaction.amount));
    final descriptionController =
        TextEditingController(text: transaction.description);
    String selectedCategory = transaction.category.toString();

    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount field
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              // Description field
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              // Category dropdown
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: TransactionCategory.values.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.toString(),
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Parse amount
              double? amount;
              try {
                amount = double.parse(amountController.text
                    .replaceAll(FormattingUtils.currencySymbol, '')
                    .replaceAll(',', ''));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid amount format'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              // Get description
              final description = descriptionController.text.trim();
              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Description cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              // Dispatch edit transaction event to the bloc
              context.read<TransactionAnalysisBloc>().add(
                    EditTransactionEvent(
                      transactionId: transaction.id,
                      amount: amount,
                      category: selectedCategory,
                      description: description,
                    ),
                  );
              // Show a snackbar to indicate the transaction is being updated
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Updating transaction: $description'),
                  duration: const Duration(seconds: 2),
                ),
              );
              // Refresh data after a short delay to ensure the backend has processed the update
              Future.delayed(const Duration(milliseconds: 500), _refreshData);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// A widget that lets users filter transactions by category.
/// It functions similarly to your MealTypeSelector.
class TransactionCategorySelector extends StatelessWidget {
  final TransactionCategory? selectedCategory;
  final Function(TransactionCategory?) onCategorySelected;

  const TransactionCategorySelector({
    Key? key,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // List of categories including "All" (represented by null)
    final categories = <TransactionCategory?>[
      null,
      TransactionCategory.dining,
      TransactionCategory.transport,
      TransactionCategory.entertainment,
      TransactionCategory.shopping,
      TransactionCategory.housing,
      TransactionCategory.savingsAndInvestments,
      TransactionCategory.groceries,
      TransactionCategory.other,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = category == selectedCategory ||
              (category == null && selectedCategory == null);
          final displayName = category == null ? "All" : category.displayName;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ChoiceChip(
              label: Text(
                displayName,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFfd7835) : Colors.black,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                onCategorySelected(category);
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: const Color(0xFFfd7835).withAlpha(77),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Reusable DateSelector widget (similar to your calorie history screen).
/// Passing `showMonth: false` will hide the month/year label.
class DateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final bool showMonth;

  const DateSelector({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    this.showMonth = true,
  }) : super(key: key);

  @override
  _DateSelectorState createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  late ScrollController _scrollController;
  late List<DateTime> _dates;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  void _initializeDates() {
    // Generate dates for the current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    _dates = List.generate(daysInMonth, (index) {
      return DateTime(now.year, now.month, index + 1);
    });

    // Find the index of the selected date
    _selectedIndex = _dates.indexWhere((date) =>
        date.year == widget.selectedDate.year &&
        date.month == widget.selectedDate.month &&
        date.day == widget.selectedDate.day);

    if (_selectedIndex < 0) {
      _selectedIndex = now.day - 1; // Default to "today" if not found
    }
  }

  void _scrollToToday() {
    if (_scrollController.hasClients) {
      const itemWidth = 60.0; // Approximate width of each date item
      final screenWidth = MediaQuery.of(context).size.width;
      final offset =
          (_selectedIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showMonth)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _dates.length,
            itemBuilder: (context, index) {
              final date = _dates[index];
              final isSelected = date.year == widget.selectedDate.year &&
                  date.month == widget.selectedDate.month &&
                  date.day == widget.selectedDate.day;
              final isToday = date.day == DateTime.now().day &&
                  date.month == DateTime.now().month &&
                  date.year == DateTime.now().year;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  widget.onDateSelected(date);
                },
                child: Container(
                  width: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isToday ? Color(0xFFfd7835) : Color(0xFFfd7835)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getMonthAbbreviation(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getMonthAbbreviation(DateTime date) {
    final month = DateFormat('MMM').format(date);
    return month.substring(0, 3);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

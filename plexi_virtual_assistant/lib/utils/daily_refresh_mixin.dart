mixin DailyRefreshMixin {
  DateTime? _lastRefreshDate;
  bool _hasCheckedToday = false;

  bool shouldRefresh() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If we've already checked today and refreshed, don't refresh again
    if (_hasCheckedToday && _lastRefreshDate != null && 
        _lastRefreshDate!.year == today.year && 
        _lastRefreshDate!.month == today.month && 
        _lastRefreshDate!.day == today.day) {
      return false;
    }

    // If we haven't refreshed today, do it now
    if (_lastRefreshDate == null || 
        _lastRefreshDate!.year != today.year || 
        _lastRefreshDate!.month != today.month || 
        _lastRefreshDate!.day != today.day) {
      _lastRefreshDate = today;
      _hasCheckedToday = true;
      return true;
    }
    
    return false;
  }
  
  // Call this method to force a refresh on the next check
  void resetRefreshState() {
    _hasCheckedToday = false;
  }
}

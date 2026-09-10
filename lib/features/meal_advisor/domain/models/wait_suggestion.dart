class WaitSuggestion {
  final int recommendedMinutes; // main target time
  final int minMinutes; // lower bound of window
  final int maxMinutes; // upper bound of window

  WaitSuggestion(this.recommendedMinutes, this.minMinutes, this.maxMinutes);
}

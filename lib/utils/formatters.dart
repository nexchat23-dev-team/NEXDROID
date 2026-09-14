String formatBalanceDisplay(int amount) {
  if (amount >= 1000000000000000000) {
    return '∞';
  }
  if (amount >= 1000000000000000) {
    return '${(amount / 1000000000000000).toStringAsFixed(1)}Q';
  }
  if (amount >= 1000000000000) {
    return '${(amount / 1000000000000).toStringAsFixed(1)}T';
  }
  if (amount >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}B';
  }
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toString();
}

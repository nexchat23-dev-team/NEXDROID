String cardinalDirection(double heading) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  if (heading.isNaN || heading.isInfinite) {
    return directions.first;
  }

  final normalized = heading % 360;
  final safeHeading = normalized < 0 ? normalized + 360 : normalized;
  final index = ((safeHeading + 22.5) / 45).floor() % directions.length;
  return directions[index];
}

String headingStatusLabel(double accuracy, bool isLive) {
  if (!isLive) {
    return 'Offline';
  }
  if (accuracy < 0.55) {
    return 'Calibrating';
  }
  return 'Live';
}

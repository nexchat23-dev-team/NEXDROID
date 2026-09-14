String sanitizeTrackFileName(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return cleaned.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}

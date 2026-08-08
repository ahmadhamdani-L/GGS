String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.length < 2) {
    return 'Nama minimal 2 karakter';
  }
  if (name.length > 16) {
    return 'Nama maksimal 16 karakter';
  }
  return null;
}

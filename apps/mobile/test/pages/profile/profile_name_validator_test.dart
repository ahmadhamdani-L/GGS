import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/pages/profile/profile_name_validator.dart';

void main() {
  group('validateDisplayName', () {
    test('accepts a valid display name', () {
      expect(validateDisplayName('Ari'), isNull);
    });

    test('rejects empty or too short names', () {
      expect(validateDisplayName(''), 'Nama minimal 2 karakter');
      expect(validateDisplayName('A'), 'Nama minimal 2 karakter');
    });

    test('rejects names that are too long', () {
      expect(validateDisplayName('A' * 17), 'Nama maksimal 16 karakter');
    });
  });
}

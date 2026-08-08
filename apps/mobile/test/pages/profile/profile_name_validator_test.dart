import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/pages/profile/profile_name_validator.dart';

void main() {
  test('validateDisplayName enforces length', () {
    expect(validateDisplayName(''), isNotNull);
    expect(validateDisplayName('A'), isNotNull);
    expect(validateDisplayName('AB'), isNull);
    expect(validateDisplayName('A' * 16), isNull);
    expect(validateDisplayName('A' * 17), isNotNull);
  });
}

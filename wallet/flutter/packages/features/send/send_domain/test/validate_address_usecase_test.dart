import 'package:send_domain/send_domain.dart';
import 'package:test/test.dart';

void main() {
  test('accepts stealth prefixes (qs:, qstest:)', () {
    final validate = ValidateAddressUseCase();

    expect(validate('qs:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx9awp4e'),
        isTrue);
    expect(
        validate(
            'qstest:qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqkx9awp4e'),
        isTrue);
  });

  test('does not reject long MLDSA-style addresses by length only', () {
    final validate = ValidateAddressUseCase();

    final longPayload = List.filled(2200, 'q').join();
    final candidate = 'kaspa:$longPayload';
    expect(validate(candidate), isTrue);
  });
}

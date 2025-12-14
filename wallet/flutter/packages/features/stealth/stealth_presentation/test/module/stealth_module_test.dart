import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_presentation/stealth_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('StealthModule', () {
    test('expects AccountRepository, TransactionRepository', () {
      final module = StealthModule();

      expect(
        module.expects,
        containsAll([
          AccountRepository,
          TransactionRepository,
        ]),
      );
    });

    test('has no submodules', () {
      final module = StealthModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = StealthModule();
      final module2 = StealthModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

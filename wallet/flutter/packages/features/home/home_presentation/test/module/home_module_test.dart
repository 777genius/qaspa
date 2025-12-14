import 'package:flutter_test/flutter_test.dart';
import 'package:home_presentation/home_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('HomeModule', () {
    test('expects WalletRepository, AccountRepository, TransactionRepository',
        () {
      final module = HomeModule();

      expect(
        module.expects,
        containsAll([
          WalletRepository,
          AccountRepository,
          TransactionRepository,
        ]),
      );
    });

    test('has no submodules', () {
      final module = HomeModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = HomeModule();
      final module2 = HomeModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

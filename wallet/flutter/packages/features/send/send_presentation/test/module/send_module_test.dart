import 'package:flutter_test/flutter_test.dart';
import 'package:send_presentation/send_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('SendModule', () {
    test('expects AccountRepository, TransactionRepository', () {
      final module = SendModule();

      expect(
        module.expects,
        containsAll([
          AccountRepository,
          TransactionRepository,
        ]),
      );
    });

    test('has no submodules', () {
      final module = SendModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = SendModule();
      final module2 = SendModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

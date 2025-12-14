import 'package:flutter_test/flutter_test.dart';
import 'package:receive_presentation/receive_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('ReceiveModule', () {
    test('expects AccountRepository', () {
      final module = ReceiveModule();

      expect(module.expects, contains(AccountRepository));
    });

    test('has no submodules', () {
      final module = ReceiveModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = ReceiveModule();
      final module2 = ReceiveModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

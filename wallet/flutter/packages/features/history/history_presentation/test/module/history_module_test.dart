import 'package:flutter_test/flutter_test.dart';
import 'package:history_presentation/history_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('HistoryModule', () {
    test('expects TransactionRepository', () {
      final module = HistoryModule();

      expect(module.expects, contains(TransactionRepository));
    });

    test('has no submodules', () {
      final module = HistoryModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = HistoryModule();
      final module2 = HistoryModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

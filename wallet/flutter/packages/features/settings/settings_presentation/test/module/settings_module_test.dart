import 'package:flutter_test/flutter_test.dart';
import 'package:settings_presentation/settings_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('SettingsModule', () {
    test('expects WalletRepository', () {
      final module = SettingsModule();

      expect(module.expects, contains(WalletRepository));
    });

    test('has no submodules', () {
      final module = SettingsModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = SettingsModule();
      final module2 = SettingsModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

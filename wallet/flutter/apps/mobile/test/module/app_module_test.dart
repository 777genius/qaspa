import 'package:flutter_test/flutter_test.dart';
import 'package:kaspa_wallet_mobile/src/app_module.dart';

void main() {
  group('AppModule', () {
    test('has 7 submodules', () {
      final module = AppModule();

      expect(module.submodules, hasLength(7));
    });

    test('expects no dependencies (root module)', () {
      final module = AppModule();

      expect(module.expects, isEmpty);
    });

    test('submodules contain all expected feature modules', () {
      final module = AppModule();
      final submoduleTypes =
          module.submodules.map((m) => m.runtimeType.toString()).toList();

      expect(
          submoduleTypes,
          containsAll([
            'OnboardingModule',
            'HomeModule',
            'SendModule',
            'ReceiveModule',
            'HistoryModule',
            'SettingsModule',
            'StealthModule',
          ]));
    });

    test('module can be instantiated multiple times', () {
      final module1 = AppModule();
      final module2 = AppModule();

      expect(module1.submodules.length, equals(module2.submodules.length));
    });
  });
}

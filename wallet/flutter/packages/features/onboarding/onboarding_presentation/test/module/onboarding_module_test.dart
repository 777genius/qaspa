import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding_presentation/onboarding_presentation.dart';
import 'package:wallet_domain/wallet_domain.dart';

void main() {
  group('OnboardingModule', () {
    test('expects WalletRepository', () {
      final module = OnboardingModule();

      expect(module.expects, contains(WalletRepository));
    });

    test('has no submodules', () {
      final module = OnboardingModule();

      expect(module.submodules, isEmpty);
    });

    test('module can be instantiated multiple times', () {
      final module1 = OnboardingModule();
      final module2 = OnboardingModule();

      expect(module1.expects, equals(module2.expects));
    });
  });
}

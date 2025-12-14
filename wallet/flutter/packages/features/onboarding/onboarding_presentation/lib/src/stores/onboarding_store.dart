import 'dart:developer' as developer;

import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:onboarding_domain/onboarding_domain.dart';
import 'package:wallet_domain/wallet_domain.dart';

part 'onboarding_store.g.dart';

/// MobX store for managing onboarding flow state.
@lazySingleton
class OnboardingStore = _OnboardingStoreBase with _$OnboardingStore;

abstract class _OnboardingStoreBase with Store {
  final GenerateMnemonicUseCase _generateMnemonicUseCase;
  final ValidateMnemonicUseCase _validateMnemonicUseCase;
  final VerifyMnemonicUseCase _verifyMnemonicUseCase;
  final CreateWalletUseCase _createWalletUseCase;
  final ImportWalletUseCase _importWalletUseCase;
  final Bip39WordlistService _wordlistService;

  _OnboardingStoreBase({
    required GenerateMnemonicUseCase generateMnemonicUseCase,
    required ValidateMnemonicUseCase validateMnemonicUseCase,
    required VerifyMnemonicUseCase verifyMnemonicUseCase,
    required CreateWalletUseCase createWalletUseCase,
    required ImportWalletUseCase importWalletUseCase,
    required Bip39WordlistService wordlistService,
  })  : _generateMnemonicUseCase = generateMnemonicUseCase,
        _validateMnemonicUseCase = validateMnemonicUseCase,
        _verifyMnemonicUseCase = verifyMnemonicUseCase,
        _createWalletUseCase = createWalletUseCase,
        _importWalletUseCase = importWalletUseCase,
        _wordlistService = wordlistService;

  // ============================================================================
  // Observables
  // ============================================================================

  /// Current onboarding flow (create or import)
  @observable
  OnboardingFlow? flow;

  /// Current step in the flow
  @observable
  OnboardingStep currentStep = OnboardingStep.welcome;

  /// Generated mnemonic for create flow
  @observable
  Mnemonic? mnemonic;

  /// Whether mnemonic is revealed on backup screen
  @observable
  bool isMnemonicRevealed = false;

  /// Whether user confirmed backup
  @observable
  bool isBackupConfirmed = false;

  /// Imported words for import flow
  @observable
  ObservableList<String> importedWords = ObservableList<String>.of(
    List.filled(24, ''),
  );

  /// Mnemonic verification state
  @observable
  MnemonicVerification? verification;

  /// Current password
  @observable
  String password = '';

  /// Confirm password
  @observable
  String confirmPassword = '';

  /// Selected network
  @observable
  NetworkId selectedNetwork = NetworkId.mainnet;

  /// Loading state
  @observable
  bool isLoading = false;

  /// Error message
  @observable
  String? errorMessage;

  /// Created/imported wallet
  @observable
  Wallet? createdWallet;

  /// Wallet name
  @observable
  String walletName = 'My Wallet';

  // ============================================================================
  // Computed
  // ============================================================================

  /// Can proceed from generate step
  @computed
  bool get canProceedFromGenerate => mnemonic != null && !isLoading;

  /// Can proceed from backup step
  @computed
  bool get canProceedFromBackup =>
      mnemonic != null && isBackupConfirmed && isMnemonicRevealed;

  /// Can proceed from verify step
  @computed
  bool get canProceedFromVerify {
    final v = verification;
    return v != null && v.isComplete && v.isAllCorrect;
  }

  /// Can proceed from import step
  @computed
  bool get canProceedFromImport {
    final nonEmptyWords = importedWords.where((w) => w.isNotEmpty).toList();
    if (nonEmptyWords.length != 24 && nonEmptyWords.length != 12) return false;
    return _validateMnemonicUseCase.execute(nonEmptyWords);
  }

  /// Can proceed from password step
  @computed
  bool get canProceedFromPassword =>
      passwordStrength.level >= 2 && passwordsMatch;

  /// Password strength
  @computed
  PasswordStrengthLevel get passwordStrength {
    if (password.isEmpty) return PasswordStrengthLevel.none;
    if (password.length < 8) return PasswordStrengthLevel.weak;

    var score = 0;
    if (password.length >= 12) score += 2;
    else if (password.length >= 10) score += 1;

    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) return PasswordStrengthLevel.weak;
    if (score <= 4) return PasswordStrengthLevel.fair;
    if (score <= 5) return PasswordStrengthLevel.good;
    return PasswordStrengthLevel.strong;
  }

  /// Whether passwords match
  @computed
  bool get passwordsMatch =>
      password.isNotEmpty && password == confirmPassword;

  /// Word suggestions for import autocomplete
  List<String> getSuggestions(String prefix) {
    return _wordlistService.searchByPrefix(prefix, limit: 5);
  }

  /// Check if imported word at index is valid
  bool isWordValid(int index) {
    if (index >= importedWords.length) return false;
    final word = importedWords[index];
    return word.isNotEmpty && _wordlistService.isValidWord(word);
  }

  /// Number of valid imported words
  @computed
  int get validImportedWordsCount =>
      importedWords.where((w) => w.isNotEmpty && _wordlistService.isValidWord(w)).length;

  /// Verification progress (0-3)
  @computed
  int get verificationProgress => verification?.currentChallengeIndex ?? 0;

  /// Total steps in current flow
  @computed
  int get totalSteps {
    return switch (flow) {
      OnboardingFlow.create => 5,
      OnboardingFlow.import => 4,
      null => 1,
    };
  }

  /// Current step number (1-based)
  @computed
  int get currentStepNumber {
    return switch (currentStep) {
      OnboardingStep.welcome => 1,
      OnboardingStep.generateMnemonic => 1,
      OnboardingStep.backupMnemonic => 2,
      OnboardingStep.verifyMnemonic => 3,
      OnboardingStep.importMnemonic => 1,
      OnboardingStep.setPassword => flow == OnboardingFlow.create ? 4 : 2,
      OnboardingStep.selectNetwork => flow == OnboardingFlow.create ? 5 : 3,
      OnboardingStep.success => flow == OnboardingFlow.create ? 5 : 4,
    };
  }

  // ============================================================================
  // Actions
  // ============================================================================

  /// Select onboarding flow
  @action
  void selectFlow(OnboardingFlow selectedFlow) {
    flow = selectedFlow;
    if (selectedFlow == OnboardingFlow.create) {
      currentStep = OnboardingStep.generateMnemonic;
    } else {
      currentStep = OnboardingStep.importMnemonic;
    }
  }

  /// Generate new mnemonic
  @action
  Future<void> generateMnemonic() async {
    isLoading = true;
    errorMessage = null;

    try {
      mnemonic = await _generateMnemonicUseCase.execute();
      isMnemonicRevealed = false;
      isBackupConfirmed = false;
    } catch (e) {
      developer.log('Failed to generate mnemonic', error: e, name: 'OnboardingStore');
      errorMessage = 'Failed to generate recovery phrase. Please try again';
    } finally {
      isLoading = false;
    }
  }

  /// Reveal mnemonic on backup screen
  @action
  void revealMnemonic() {
    isMnemonicRevealed = true;
  }

  /// Confirm backup completion
  @action
  void confirmBackup() {
    isBackupConfirmed = true;
  }

  /// Proceed to verification step
  @action
  void proceedToVerification() {
    if (mnemonic == null) return;
    verification = _verifyMnemonicUseCase.execute(mnemonic!);
    currentStep = OnboardingStep.verifyMnemonic;
  }

  /// Submit verification answer
  @action
  bool submitVerificationAnswer(String selectedWord) {
    if (verification == null || verification!.isComplete) return false;

    final currentChallenge = verification!.currentChallenge;
    final isCorrect = currentChallenge?.isCorrect(selectedWord) ?? false;

    verification = verification!.answerCurrent(selectedWord);

    return isCorrect;
  }

  /// Set imported word at index
  @action
  void setImportedWord(int index, String word) {
    if (index >= importedWords.length) return;
    importedWords[index] = word.toLowerCase().trim();
  }

  /// Validate imported mnemonic and proceed
  @action
  Future<void> validateImportedMnemonic() async {
    final words = importedWords.where((w) => w.isNotEmpty).toList();
    final result = _validateMnemonicUseCase.validateWithDetails(words);

    if (!result.isValid) {
      errorMessage = result.errorMessage;
      return;
    }

    errorMessage = null;
    currentStep = OnboardingStep.setPassword;
  }

  /// Set password
  @action
  void setPassword(String value) {
    password = value.trim();
  }

  /// Set confirm password
  @action
  void setConfirmPassword(String value) {
    confirmPassword = value.trim();
  }

  /// Set wallet name
  @action
  void setWalletName(String value) {
    walletName = value.trim();
  }

  /// Select network
  @action
  void selectNetwork(NetworkId network) {
    selectedNetwork = network;
  }

  /// Proceed to next step
  @action
  void proceedToNextStep() {
    currentStep = switch (currentStep) {
      OnboardingStep.welcome => OnboardingStep.welcome,
      OnboardingStep.generateMnemonic => OnboardingStep.backupMnemonic,
      OnboardingStep.backupMnemonic => OnboardingStep.verifyMnemonic,
      OnboardingStep.verifyMnemonic => OnboardingStep.setPassword,
      OnboardingStep.importMnemonic => OnboardingStep.setPassword,
      OnboardingStep.setPassword => OnboardingStep.selectNetwork,
      OnboardingStep.selectNetwork => OnboardingStep.success,
      OnboardingStep.success => OnboardingStep.success,
    };
  }

  /// Create wallet (final step)
  @action
  Future<void> createWallet() async {
    isLoading = true;
    errorMessage = null;

    try {
      if (flow == OnboardingFlow.create) {
        createdWallet = await _createWalletUseCase.execute(
          name: walletName,
          password: password,
          networkId: selectedNetwork,
        );
      } else {
        final words = importedWords.where((w) => w.isNotEmpty).toList();
        createdWallet = await _importWalletUseCase.execute(
          name: walletName,
          password: password,
          words: words,
          networkId: selectedNetwork,
        );
      }
      // Clear sensitive data after successful wallet creation
      clearSensitiveData();
      currentStep = OnboardingStep.success;
    } catch (e) {
      developer.log('Wallet creation failed', error: e, name: 'OnboardingStore');
      errorMessage = _getWalletCreationErrorMessage(e);
    } finally {
      isLoading = false;
    }
  }

  String _getWalletCreationErrorMessage(Object error) {
    if (error is InvalidMnemonicException) {
      return 'Invalid recovery phrase';
    } else if (error is InvalidPasswordException) {
      return 'Invalid password';
    } else if (error is WalletAlreadyExistsException) {
      return 'A wallet with this name already exists';
    }
    return 'Failed to create wallet. Please try again';
  }

  /// Reset store to initial state
  @action
  void reset() {
    flow = null;
    currentStep = OnboardingStep.welcome;
    mnemonic = null;
    isMnemonicRevealed = false;
    isBackupConfirmed = false;
    importedWords = ObservableList<String>.of(List.filled(24, ''));
    verification = null;
    clearSensitiveData();
    selectedNetwork = NetworkId.mainnet;
    isLoading = false;
    errorMessage = null;
    createdWallet = null;
    walletName = 'My Wallet';
  }

  /// Dispose the store and clear all sensitive data.
  void dispose() {
    clearSensitiveData();
  }

  /// Clear sensitive data from memory (passwords, mnemonic, imported words).
  /// Should be called after wallet creation and in dispose().
  @action
  void clearSensitiveData() {
    // Clear passwords
    password = '';
    confirmPassword = '';

    // Clear mnemonic from create flow
    mnemonic = null;
    isMnemonicRevealed = false;

    // Clear imported words - overwrite with empty strings
    importedWords = ObservableList<String>.of(List.filled(24, ''));

    // Clear verification state
    verification = null;
  }

  /// Go back to previous step
  @action
  void goBack() {
    currentStep = switch (currentStep) {
      OnboardingStep.welcome => OnboardingStep.welcome,
      OnboardingStep.generateMnemonic => OnboardingStep.welcome,
      OnboardingStep.backupMnemonic => OnboardingStep.generateMnemonic,
      OnboardingStep.verifyMnemonic => OnboardingStep.backupMnemonic,
      OnboardingStep.importMnemonic => OnboardingStep.welcome,
      OnboardingStep.setPassword => flow == OnboardingFlow.create
          ? OnboardingStep.verifyMnemonic
          : OnboardingStep.importMnemonic,
      OnboardingStep.selectNetwork => OnboardingStep.setPassword,
      OnboardingStep.success => OnboardingStep.success,
    };
  }
}

/// Onboarding flow types.
enum OnboardingFlow {
  create,
  import,
}

/// Onboarding steps.
enum OnboardingStep {
  welcome,
  generateMnemonic,
  backupMnemonic,
  verifyMnemonic,
  importMnemonic,
  setPassword,
  selectNetwork,
  success,
}

/// Password strength levels.
enum PasswordStrengthLevel {
  none(0),
  weak(1),
  fair(2),
  good(3),
  strong(4);

  final int level;
  const PasswordStrengthLevel(this.level);
}

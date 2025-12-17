import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../stores/settings_store.dart';

/// Page to change wallet password.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;

  @override
  void dispose() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ModuleProvider.of(context).get<SettingsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Observer(
        builder: (_) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: !_currentPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _currentPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      tooltip: _currentPasswordVisible ? 'Hide password' : 'Show password',
                      onPressed: () {
                        setState(() =>
                            _currentPasswordVisible = !_currentPasswordVisible);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_newPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _newPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      tooltip: _newPasswordVisible ? 'Hide password' : 'Show password',
                      onPressed: () {
                        setState(
                            () => _newPasswordVisible = !_newPasswordVisible);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter new password';
                    }
                    if (value.trim().length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_newPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _newPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      tooltip: _newPasswordVisible ? 'Hide password' : 'Show password',
                      onPressed: () {
                        setState(
                            () => _newPasswordVisible = !_newPasswordVisible);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value?.trim() != _newPasswordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (store.errorMessage case final errorMsg?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    errorMsg,
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
                if (store.successMessage case final successMsg?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    successMsg,
                    style: TextStyle(color: AppColors.success),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: store.isProcessing
                      ? null
                      : () async {
                          store.clearMessages();
                          if (_formKey.currentState!.validate()) {
                            try {
                              final success = await store.changePassword(
                                currentPassword: _currentPasswordController.text,
                                newPassword: _newPasswordController.text,
                              );

                              // Check mounted before any UI updates
                              if (!mounted) return;

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password changed successfully'),
                                  ),
                                );
                                context.pop();
                              }
                            } finally {
                              // Always clear passwords from memory for security
                              _currentPasswordController.clear();
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                            }
                          }
                        },
                  child: store.isProcessing
                      ? const CircularProgressIndicator()
                      : const Text('Change Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await fetchUserProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.accountLogoutDialogTitle,
      content: l10n.accountLogoutDialogBody,
      confirmLabel: l10n.accountLogoutConfirm,
      isDanger: true,
      icon: LucideIcons.logOut,
    );
    if (!confirmed || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (_) => _DeleteAccountDialog(email: _profile?.email ?? ''),
    );
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(email: _profile?.email ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountScreenTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.contentMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.user,
                          size: 36,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        _profile?.username ?? '',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Center(
                      child: Text(
                        _profile?.email ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton(
                              onPressed: _changePassword,
                              child: Text(l10n.accountChangePassword),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              onPressed: _deleteAccount,
                              style: TextButton.styleFrom(
                                foregroundColor: colors.textTertiary,
                              ),
                              child: Text(l10n.accountDeleteAccount),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton(
                              onPressed: _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.danger,
                                side: BorderSide(
                                  color: colors.danger.withValues(alpha: 0.34),
                                ),
                              ),
                              child: Text(l10n.accountLogout),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

}

class _ChangePasswordDialog extends StatefulWidget {
  final String email;
  const _ChangePasswordDialog({required this.email});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _codeSending = false;
  bool _submitting = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _error = null;
      _codeSending = true;
    });
    try {
      await sendChangePasswordCode();
      if (!mounted) return;
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _codeSending = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).accountValidationEnterVerificationCode);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await changePassword(code: code, newPassword: _newCtrl.text);
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.show(
        context,
        message: AppLocalizations.of(context).accountPasswordChangedToast,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final codeEmpty = _codeCtrl.text.trim().isEmpty;
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final viewInsets = media.viewInsets;
    final dialogWidth = screenWidth <= AppSize.formMaxWidth + 32
        ? screenWidth - 32
        : AppSize.formMaxWidth;
    const verticalInset = 24.0;
    final maxDialogHeight = media.size.height -
        media.padding.top -
        media.padding.bottom -
        viewInsets.top -
        viewInsets.bottom -
        verticalInset * 2;

    return Dialog(
      insetPadding: EdgeInsets.only(
        left: AppDialog.insetPadding.left,
        right: AppDialog.insetPadding.right,
        top: verticalInset,
        bottom: verticalInset + viewInsets.bottom,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: maxDialogHeight > 0 ? maxDialogHeight : media.size.height * 0.5,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(l10n.accountChangePasswordTitle,
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        foregroundColor: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.accountChangePasswordWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  widget.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.dangerSurface,
                      borderRadius: AppRadius.small,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: colors.danger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: l10n.accountLabelVerificationCode,
                          hintText: l10n.accountHintSixDigitCode,
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.accountValidationEnterVerificationCode
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 100,
                      child: FilledButton(
                        onPressed: (_codeSending || _cooldown > 0) ? null : _sendCode,
                        child: Text(
                          _codeSending
                              ? l10n.accountSendingCode
                              : _cooldown > 0
                                  ? l10n.codeCooldownSeconds(_cooldown)
                                  : l10n.accountSendVerificationCode,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.accountLabelNewPassword,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.accountValidationEnterNewPassword;
                    }
                    if (v.length < 6) {
                      return l10n.accountValidationNewPasswordMinLength;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.accountLabelConfirmNewPassword,
                  ),
                  validator: (v) {
                    if (v != _newCtrl.text) {
                      return l10n.accountValidationPasswordMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: (_submitting || codeEmpty) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.confirm),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  final String email;
  const _DeleteAccountDialog({required this.email});

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _codeCtrl = TextEditingController();
  bool _codeSending = false;
  bool _submitting = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _error = null;
      _codeSending = true;
    });
    try {
      await sendDeleteAccountCode();
      if (!mounted) return;
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _codeSending = false);
    }
  }

  Future<void> _confirmDelete() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).accountValidationEnterVerificationCode);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await confirmDeleteAccount(code);
      await ref.read(authProvider.notifier).clearAuth();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final codeEmpty = _codeCtrl.text.trim().isEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.formMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.accountDeleteTitle, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      foregroundColor: colors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.accountDeleteWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                widget.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.dangerSurface,
                    borderRadius: AppRadius.small,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colors.danger, fontSize: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: l10n.accountLabelVerificationCode,
                        hintText: l10n.accountHintSixDigitCode,
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 100,
                    child: FilledButton(
                      onPressed: (_codeSending || _cooldown > 0)
                          ? null
                          : _sendCode,
                      child: Text(
                        _codeSending
                            ? l10n.accountSendingCode
                            : _cooldown > 0
                                ? l10n.codeCooldownSeconds(_cooldown)
                                : l10n.accountSendVerificationCode,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: (_submitting || codeEmpty) ? null : _confirmDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.accountDeleteForever),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

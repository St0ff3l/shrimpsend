import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/otp_input.dart';

class MembershipMigrationScreen extends StatefulWidget {
  const MembershipMigrationScreen({super.key});

  @override
  State<MembershipMigrationScreen> createState() => _MembershipMigrationScreenState();
}

class _MembershipMigrationScreenState extends State<MembershipMigrationScreen> {
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _codeSending = false;
  int _codeCooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _mobileController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _codeCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _codeCooldown--;
        if (_codeCooldown <= 0) {
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      setState(() => _error = l10n.membershipMigrationEnterPhone);
      return;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(mobile)) {
      setState(() => _error = l10n.membershipMigrationInvalidPhone);
      return;
    }
    setState(() {
      _error = null;
      _codeSending = true;
    });
    try {
      await sendMembershipMigrationCode(mobile);
      if (!mounted) return;
      _startCooldown();
      AppToast.show(context, message: l10n.membershipMigrationCodeSent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _codeSending = false);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final mobile = _mobileController.text.trim();
    final code = _codeController.text.trim();
    if (mobile.isEmpty) {
      setState(() => _error = l10n.membershipMigrationEnterPhone);
      return;
    }
    if (code.length != 6) {
      setState(() => _error = l10n.membershipMigrationEnterCode);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final response = await verifyMembershipMigration(mobile: mobile, code: code);
      if (!mounted) return;
      if (response.success) {
        _showConfirmDialog(response);
      } else {
        setState(() => _error = response.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantMembership(MembershipMigrationVerifyResponse response) async {
    setState(() => _loading = true);
    try {
      final mobile = _mobileController.text.trim();
      final grantResponse = await grantMembershipMigration(mobile: mobile);
      if (!mounted) return;
      if (grantResponse.success) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).membershipMigrationSuccess,
        );
        Navigator.of(context).pop(true); // 返回true表示迁移成功
      } else {
        setState(() => _error = grantResponse.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showConfirmDialog(MembershipMigrationVerifyResponse response) {
    final l10n = AppLocalizations.of(context);
    AppConfirmDialog.show(
      context,
      title: l10n.membershipMigrationConfirmTitle,
      content: l10n.membershipMigrationConfirmBody(
        response.tierName ?? '',
        response.deviceLimit ?? 0,
      ),
      confirmLabel: l10n.membershipMigrationConfirmAction,
    ).then((confirmed) {
      if (confirmed) _grantMembership(response);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.membershipMigrationTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.membershipMigrationIntroTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.membershipMigrationIntroBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.membershipMigrationPhoneLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: l10n.membershipMigrationPhoneHint,
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.membershipMigrationCodeLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OtpInput(
                        controller: _codeController,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (_codeCooldown > 0 || _codeSending)
                                  ? null
                                  : _sendCode,
                              child: Text(
                                _codeSending
                                    ? l10n.membershipMigrationSending
                                    : _codeCooldown > 0
                                        ? l10n.membershipMigrationCooldownSeconds(
                                            _codeCooldown,
                                          )
                                        : l10n.membershipMigrationSendCode,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: colors.dangerSurface,
                            borderRadius: AppRadius.small,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, size: 16, color: colors.danger),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: _loading ? null : _verify,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, AppSize.controlHeight),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.membershipMigrationVerifyAndMigrate),
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

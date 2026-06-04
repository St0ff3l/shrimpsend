import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api/api.dart';
import '../device_id.dart';
import '../logger.dart';
import '../l10n/app_brand.dart';
import '../l10n/generated/app_localizations.dart';
import '../preferences/locale_region_store.dart';
import '../providers/auth_provider.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';

class QrDisplayScreen extends ConsumerStatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen> {
  String? _sessionId;
  String _status = 'loading';
  Timer? _pollTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() {
      _status = 'loading';
      _sessionId = null;
      _error = null;
    });
    _pollTimer?.cancel();
    try {
      final sid = await createQrSession();
      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _status = 'PENDING';
      });
      _startPolling(sid);
    } catch (e) {
      logAuth.warning('qr_display create failed: $e');
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _error = formatApiError(e);
      });
      Analytics.track(AnalyticsEvents.qrLoginOutcome, {
        'side': 'display',
        'status': 'error',
        'stage': 'create_session',
      });
    }
  }

  void _startPolling(String sessionId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await getQrStatus(
          sessionId,
          deviceId: await getOrCreateDeviceId(),
          platform: await getAuthPlatformLabel(),
        );
        if (!mounted) return;
        if (res.status == 'SCANNED') {
          setState(() => _status = 'SCANNED');
        } else if (res.status == 'CONFIRMED' &&
            res.accessToken != null &&
            res.refreshToken != null &&
            res.userId != null) {
          _pollTimer?.cancel();
          setState(() => _status = 'CONFIRMED');
          final auth = AuthResponse(
            accessToken: res.accessToken!,
            refreshToken: res.refreshToken!,
            userId: res.userId!,
          );
          await ref.read(authProvider.notifier).login(auth);
          logAuth.info('qr_display login success userId=${res.userId}');
          Analytics.track(AnalyticsEvents.qrLoginOutcome, {
            'side': 'display',
            'status': 'confirmed',
          });
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (res.status == 'EXPIRED' || res.status == 'CANCELLED') {
          _pollTimer?.cancel();
          setState(() => _status = 'EXPIRED');
          Analytics.track(AnalyticsEvents.qrLoginOutcome, {
            'side': 'display',
            'status': 'expired',
          });
        }
      } catch (e) {
        logAuth.warning('qr_display poll failed: $e');
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _status = 'error';
            _error = formatApiError(e);
          });
        }
        Analytics.track(AnalyticsEvents.qrLoginOutcome, {
          'side': 'display',
          'status': 'error',
          'stage': 'poll',
        });
      }
    });
  }

  Widget _buildBackground(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final orbAlpha = isDark ? 0.12 : 0.18;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.primary.withValues(alpha: orbAlpha),
                  scheme.primary.withValues(alpha: 0.04),
                  scheme.primary.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.tertiary.withValues(alpha: orbAlpha * 0.85),
                  scheme.tertiary.withValues(alpha: 0.03),
                  scheme.tertiary.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final localeStore = LocaleRegionStoreScope.maybeOf(context);

    String hint;
    IconData statusIcon;
    switch (_status) {
      case 'loading':
        hint = l10n.qrGenerating;
        statusIcon = LucideIcons.loader;
        break;
      case 'PENDING':
        hint = l10n.qrHintScanWithPhone;
        statusIcon = LucideIcons.qrCode;
        break;
      case 'SCANNED':
        hint = l10n.qrHintConfirmOnPhone;
        statusIcon = LucideIcons.smartphone;
        break;
      case 'CONFIRMED':
        hint = l10n.qrHintLoginSuccess;
        statusIcon = LucideIcons.circleCheck;
        break;
      case 'EXPIRED':
        hint = l10n.qrHintExpired;
        statusIcon = LucideIcons.clock;
        break;
      default:
        hint = _error ?? l10n.qrHintGenericError;
        statusIcon = LucideIcons.circleAlert;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.qrLoginTitle),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(context),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppSize.formMaxWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.medium,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      localeStore == null
                          ? Text(
                              l10n.brandNameMainlandChina,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                              ),
                            )
                          : ValueListenableBuilder<LocaleRegionState>(
                              valueListenable: localeStore.notifier,
                              builder: (context, lr, _) {
                                return Text(
                                  brandDisplayName(context, lr.serviceRegion),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.6,
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.qrLoginTagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.qrLoginSteps,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.xl,
                          ),
                          child: Column(
                            children: [
                              if (_status == 'loading')
                                SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                )
                              else if (_sessionId != null &&
                                  (_status == 'PENDING' || _status == 'SCANNED'))
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    QrImageView(
                                      data: 'ultrasend://qr-login/$_sessionId',
                                      version: QrVersions.auto,
                                      size: 280,
                                      padding: const EdgeInsets.all(8),
                                      backgroundColor: Colors.white,
                                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    ),
                                    if (_status == 'SCANNED')
                                      Container(
                                        width: 280,
                                        height: 280,
                                        decoration: BoxDecoration(
                                          color: colors.background.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: AppRadius.medium,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.smartphone,
                                                size: 48,
                                                color: scheme.primary,
                                              ),
                                              const SizedBox(height: AppSpacing.sm),
                                              Text(
                                                l10n.qrStatusScanned,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                l10n.qrStatusConfirmPhone,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                  ],
                                )
                              else if (_status == 'CONFIRMED')
                                SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                )
                              else if (_status == 'EXPIRED' || _status == 'error')
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        statusIcon,
                                        size: 48,
                                        color: colors.textTertiary,
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Text(
                                        hint,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              if (_status != 'EXPIRED' && _status != 'error') ...[
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 18,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        hint,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_status == 'EXPIRED' || _status == 'error') ...[
                                const SizedBox(height: AppSpacing.lg),
                                OutlinedButton.icon(
                                  onPressed: _createSession,
                                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                                  label: Text(l10n.qrRefreshButton),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.qrUsePasswordLogin),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

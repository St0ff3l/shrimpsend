import 'dart:async';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../device_id.dart';
import '../logger.dart';
import '../l10n/app_brand.dart';
import '../l10n/generated/app_localizations.dart';
import '../preferences/country_cluster.dart';
import '../preferences/locale_region_store.dart';
import '../providers/auth_provider.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';
import '../widgets/legal_doc_links_row.dart';
import 'qr_display_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onOfflineMode});

  /// Bootstrap flow: enter app without signing in (offline/local features).
  final VoidCallback? onOfflineMode;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { login, register }

enum _LoginMethod { password, code }

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  _AuthMode _authMode = _AuthMode.login;
  _LoginMethod _loginMethod = _LoginMethod.password;
  bool _obscurePassword = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _code = TextEditingController();
  String? error;
  bool loading = false;
  bool codeSending = false;
  int codeCooldown = 0;
  Timer? _cooldownTimer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  bool get _isRegister => _authMode == _AuthMode.register;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cooldownTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _username.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => codeCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        codeCooldown--;
        if (codeCooldown <= 0) {
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  Future<void> _sendCode({String? type}) async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(
        () => error = AppLocalizations.of(context).loginErrorEmailRequired,
      );
      return;
    }
    setState(() {
      error = null;
      codeSending = true;
    });
    try {
      final deviceId = await getOrCreateDeviceId();
      final platform = await getAuthPlatformLabel();
      await sendVerificationCode(
        email,
        type: type,
        deviceId: type == 'LOGIN' ? deviceId : null,
        platform: type == 'LOGIN' ? platform : null,
      );
      if (!mounted) return;
      _startCooldown();
      Analytics.track(AnalyticsEvents.verificationCodeSend, {
        'code_type': type ?? 'REGISTER',
        'result': 'success',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = formatApiError(e));
      Analytics.track(AnalyticsEvents.verificationCodeSend, {
        'code_type': type ?? 'REGISTER',
        'result': 'fail',
      });
    } finally {
      if (mounted) setState(() => codeSending = false);
    }
  }

  Future<void> _sendCodeForLogin() async {
    await _sendCode(type: 'LOGIN');
  }

  Future<void> _submitCodeLogin() async {
    final email = _email.text.trim();
    final code = _code.text.trim();
    if (code.length != 6) {
      if (!mounted) return;
      setState(
        () => error = AppLocalizations.of(context).loginErrorCodeSixDigits,
      );
      return;
    }
    setState(() {
      error = null;
      loading = true;
    });
    try {
      final deviceId = await getOrCreateDeviceId();
      final platform = await getAuthPlatformLabel();
      final auth = await loginByCode(
        email,
        code,
        deviceId: deviceId,
        platform: platform,
      );
      await ref.read(authProvider.notifier).login(auth);
      if (!mounted) return;
      logAuth.info('login_screen code login success, back to chat');
      Analytics.track(AnalyticsEvents.loginCodeSubmit, {
        'result': 'success',
        'length_bucket': Analytics.lengthBucket(code.length),
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      logAuth.warning('login_screen code login failed: $e');
      setState(() => error = formatApiError(e));
      Analytics.track(AnalyticsEvents.loginCodeSubmit, {
        'result': 'fail',
        'length_bucket': Analytics.lengthBucket(code.length),
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    logAuth.info(
      'login_screen submit ${_isRegister ? "register" : "login"} email=$email',
    );
    setState(() {
      error = null;
      loading = true;
    });
    try {
      final deviceId = await getOrCreateDeviceId();
      final platform = await getAuthPlatformLabel();
      final auth = _isRegister
          ? await register(
              email,
              _password.text,
              _code.text.trim(),
              username: _username.text.trim().isEmpty
                  ? null
                  : _username.text.trim(),
              deviceId: deviceId,
              platform: platform,
            )
          : await login(
              email,
              _password.text,
              deviceId: deviceId,
              platform: platform,
            );
      await ref.read(authProvider.notifier).login(auth);
      if (!mounted) return;
      logAuth.info('login_screen success, back to chat');
      Analytics.track(
        _isRegister
            ? AnalyticsEvents.registerSubmit
            : AnalyticsEvents.loginSubmit,
        {
          'result': 'success',
          'length_bucket': Analytics.lengthBucket(email.length),
        },
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      logAuth.warning('login_screen failed: $e');
      setState(() => error = formatApiError(e));
      Analytics.track(
        _isRegister
            ? AnalyticsEvents.registerSubmit
            : AnalyticsEvents.loginSubmit,
        {
          'result': 'fail',
          'length_bucket': Analytics.lengthBucket(email.length),
        },
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _goQrLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QrDisplayScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final localeStore = LocaleRegionStoreScope.maybeOf(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: widget.onOfflineMode == null,
        leading: widget.onOfflineMode != null
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushReplacementNamed('/');
                  }
                },
              ),
        titleSpacing: AppSpacing.sm,
        actionsPadding: const EdgeInsets.only(right: AppSpacing.md),
        title: Padding(
          padding: EdgeInsets.only(
            left: widget.onOfflineMode != null ? AppSpacing.lg : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              localeStore == null
                  ? Text(
                      l10n.brandNameMainlandChina,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    )
                  : ValueListenableBuilder<LocaleRegionState>(
                      valueListenable: localeStore.notifier,
                      builder: (context, lr, _) {
                        return Text(
                          brandDisplayName(context, lr.serviceRegion),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        );
                      },
                    ),
              Text(
                _isRegister
                    ? l10n.loginTitleSubtitleRegister
                    : l10n.loginTitleSubtitleLogin,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        actions: [_buildCountryRegionAction(context, theme, colors, l10n)],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildLoginBackground(scheme, colors, isDark),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSize.formMaxWidth,
                          ),
                          child: Column(
                            mainAxisAlignment: widget.onOfflineMode != null
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLogoHero(),
                              const SizedBox(height: AppSpacing.lg),
                              _buildModeSegment(theme, colors, l10n),
                              const SizedBox(height: AppSpacing.lg),
                              _buildFormCard(
                                theme,
                                colors,
                                scheme,
                                l10n,
                                isDark,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              const LegalDocLinksRow(compact: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs(ColorScheme scheme, bool isDark) {
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

  Widget _buildLoginBackground(
    ColorScheme scheme,
    AppThemeColors colors,
    bool isDark,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackgroundOrbs(scheme, isDark),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.background.withValues(alpha: isDark ? 0.62 : 0.70),
                  Colors.transparent,
                  colors.background.withValues(alpha: isDark ? 0.52 : 0.62),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoHero() {
    return Align(
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: AppRadius.medium,
        child: Image.asset(
          'assets/logo.png',
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildModeSegment(
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) {
    return Align(
      alignment: Alignment.center,
      child: IntrinsicWidth(
        child: SegmentedButton<_AuthMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment<_AuthMode>(
              value: _AuthMode.login,
              label: Text(l10n.loginTabLogin),
              icon: Icon(LucideIcons.logIn, size: 18),
            ),
            ButtonSegment<_AuthMode>(
              value: _AuthMode.register,
              label: Text(l10n.loginTabRegister),
              icon: Icon(LucideIcons.userPlus, size: 18),
            ),
          ],
          selected: {_authMode},
          onSelectionChanged: (Set<_AuthMode> selected) {
            setState(() {
              _authMode = selected.first;
              error = null;
              if (_authMode == _AuthMode.login) {
                _loginMethod = _LoginMethod.password;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(
    ThemeData theme,
    AppThemeColors colors,
    ColorScheme scheme,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Card(
      elevation: isDark ? 1 : 2,
      shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.42 : 0.14),
      surfaceTintColor: scheme.surfaceTint.withValues(
        alpha: isDark ? 0.14 : 0.08,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.large,
        side: BorderSide(
          color: colors.borderStrong.withValues(alpha: isDark ? 0.5 : 0.85),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRegister ? l10n.loginTabRegister : l10n.loginTabLogin,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_authMode == _AuthMode.login) ...[
              Align(
                alignment: Alignment.center,
                child: IntrinsicWidth(
                  child: SegmentedButton<_LoginMethod>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return scheme.primaryContainer.withValues(alpha: 0.6);
                        }
                        return colors.surfaceMuted;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return scheme.onPrimaryContainer;
                        }
                        return colors.textSecondary;
                      }),
                    ),
                    segments: [
                      ButtonSegment<_LoginMethod>(
                        value: _LoginMethod.password,
                        label: Text(l10n.loginMethodPassword),
                        icon: Icon(LucideIcons.lock, size: 14),
                      ),
                      ButtonSegment<_LoginMethod>(
                        value: _LoginMethod.code,
                        label: Text(l10n.loginMethodCode),
                        icon: Icon(LucideIcons.mail, size: 14),
                      ),
                    ],
                    selected: {_loginMethod},
                    onSelectionChanged: (Set<_LoginMethod> selected) {
                      setState(() {
                        _loginMethod = selected.first;
                        error = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.fieldEmail,
                hintText: l10n.hintEmail,
                prefixIcon: Icon(
                  LucideIcons.mail,
                  size: 18,
                  color: colors.textTertiary,
                ),
              ),
            ),
            if ((_authMode == _AuthMode.login &&
                    _loginMethod == _LoginMethod.password) ||
                _isRegister) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: _isRegister
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: _isRegister ? null : (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.fieldPassword,
                  prefixIcon: Icon(
                    LucideIcons.lock,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ],
            if (_authMode == _AuthMode.login &&
                _loginMethod == _LoginMethod.code) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitCodeLogin(),
                      decoration: InputDecoration(
                        labelText: l10n.fieldVerificationCode,
                        hintText: l10n.hintVerificationCode6,
                        counterText: '',
                        prefixIcon: Icon(
                          LucideIcons.shieldCheck,
                          size: 18,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 112,
                    height: AppSize.controlHeight,
                    child: OutlinedButton(
                      onPressed: (codeSending || codeCooldown > 0)
                          ? null
                          : _sendCodeForLogin,
                      child: codeSending
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.textTertiary,
                              ),
                            )
                          : Text(
                              codeCooldown > 0
                                  ? l10n.codeCooldownSeconds(codeCooldown)
                                  : l10n.loginGetVerificationCode,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ],
              ),
            ],
            if (_isRegister) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.fieldNicknameOptional,
                  hintText: l10n.hintDisplayName,
                  prefixIcon: Icon(
                    LucideIcons.user,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
            if (_isRegister) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.fieldVerificationCode,
                        hintText: l10n.hintVerificationCode6,
                        counterText: '',
                        prefixIcon: Icon(
                          LucideIcons.shieldCheck,
                          size: 18,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 112,
                    height: AppSize.controlHeight,
                    child: OutlinedButton(
                      onPressed: (codeSending || codeCooldown > 0)
                          ? null
                          : _sendCode,
                      child: codeSending
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.textTertiary,
                              ),
                            )
                          : Text(
                              codeCooldown > 0
                                  ? l10n.codeCooldownSeconds(codeCooldown)
                                  : l10n.loginSendVerificationCode,
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ],
              ),
            ],
            _buildError(theme, colors),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: loading
                  ? null
                  : (_isRegister
                        ? _submit
                        : (_loginMethod == _LoginMethod.code
                              ? _submitCodeLogin
                              : _submit)),
              child: loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(
                      _isRegister
                          ? l10n.loginSubmitRegister
                          : (_loginMethod == _LoginMethod.code
                                ? l10n.loginSubmitWithCode
                                : l10n.loginSubmitPassword),
                    ),
            ),
            if (_authMode == _AuthMode.login) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _goQrLogin,
                icon: const Icon(LucideIcons.qrCode, size: 18),
                label: Text(l10n.loginQrLogin),
              ),
            ],
            if (widget.onOfflineMode != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildOfflineModeButton(l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineModeButton(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: () {
        Analytics.track(AnalyticsEvents.offlineModeEnter);
        widget.onOfflineMode!();
      },
      icon: const Icon(LucideIcons.cloudOff, size: 18),
      label: Text(l10n.enterOfflineMode),
    );
  }

  Widget _buildError(ThemeData theme, AppThemeColors colors) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.dangerSurface,
          borderRadius: AppRadius.small,
          border: Border.all(color: colors.danger.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.circleAlert, size: 16, color: colors.danger),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countryLabelForCode(BuildContext context, String countryCode) {
    final c = CountryService().findByCode(countryCode);
    if (c == null) {
      return countryCode;
    }
    return c.getTranslatedName(context) ?? c.name;
  }

  /// Normalizes stored locale to `zh_CN` or `en` for the language segment control.
  Locale _localeSegmentValue(Locale locale) {
    if (locale.languageCode == 'zh') {
      return const Locale('zh', 'CN');
    }
    return const Locale('en');
  }

  String _localeEchoLabel(Locale locale, AppLocalizations l10n) {
    final v = _localeSegmentValue(locale);
    return v.languageCode == 'zh'
        ? l10n.localeNameZhHans
        : l10n.localeNameEnglish;
  }

  Widget _buildCountryRegionAction(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) {
    final store = LocaleRegionStoreScope.of(context);
    return ListenableBuilder(
      listenable: store.notifier,
      builder: (context, _) {
        final lr = store.notifier.value;
        final echo =
            '${_countryLabelForCode(context, lr.countryCode)} · ${_localeEchoLabel(lr.locale, l10n)}';
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: TextButton.icon(
              onPressed: () =>
                  _showLocaleRegionDialog(context, theme, colors, store, l10n),
              icon: Icon(
                LucideIcons.languages,
                size: 16,
                color: colors.textSecondary,
              ),
              label: Text(
                echo,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        );
      },
    );
  }

  static const _countryPickerFavorites = <String>[
    'CN',
    'US',
    'HK',
    'TW',
    'JP',
    'SG',
    'GB',
    'AU',
    'CA',
    'DE',
    'FR',
  ];

  void _showLocaleRegionDialog(
    BuildContext parentContext,
    ThemeData theme,
    AppThemeColors colors,
    LocaleRegionStore store,
    AppLocalizations l10n,
  ) {
    showDialog<void>(
      context: parentContext,
      useRootNavigator: true,
      builder: (dialogContext) {
        return ValueListenableBuilder<LocaleRegionState>(
          valueListenable: store.notifier,
          builder: (context, lr, _) {
            return AlertDialog(
              title: Text(
                LocaleRegionStore.countryLocked
                    ? l10n.sectionLanguage
                    : l10n.sectionLanguageRegion,
              ),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!LocaleRegionStore.countryLocked) ...[
                        Text(
                          l10n.fieldCountryRegion,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ListTile(
                          tileColor: colors.surfaceMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                            side: BorderSide(color: colors.borderStrong),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          title: Text(
                            _countryLabelForCode(context, lr.countryCode),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: colors.textTertiary,
                          ),
                          onTap: () {
                            showCountryPicker(
                              context: dialogContext,
                              useRootNavigator: true,
                              showWorldWide: false,
                              favorite: _countryPickerFavorites,
                              onSelect: (Country country) {
                                final dialogNav = Navigator.maybeOf(
                                  dialogContext,
                                  rootNavigator: true,
                                );
                                Future.microtask(
                                  () => _applyPickedCountry(
                                    store,
                                    lr,
                                    l10n,
                                    country,
                                    localeDialogNavigator: dialogNav,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Text(
                        l10n.fieldLanguage,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: AppRadius.medium,
                          border: Border.all(color: colors.borderStrong),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Align(
                            alignment: Alignment.center,
                            child: SegmentedButton<Locale>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment<Locale>(
                                  value: const Locale('zh', 'CN'),
                                  label: Text(l10n.localeNameZhHans),
                                ),
                                ButtonSegment<Locale>(
                                  value: const Locale('en'),
                                  label: Text(l10n.localeNameEnglish),
                                ),
                              ],
                              selected: {_localeSegmentValue(lr.locale)},
                              onSelectionChanged: (Set<Locale> selected) async {
                                final next = selected.first;
                                if (_localeSegmentValue(lr.locale) == next) {
                                  return;
                                }
                                await store.setLocale(next);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyPickedCountry(
    LocaleRegionStore store,
    LocaleRegionState current,
    AppLocalizations l10n,
    Country country, {
    NavigatorState? localeDialogNavigator,
  }) async {
    if (LocaleRegionStore.countryLocked) return;
    final newCode = country.countryCode;
    if (newCode == current.countryCode) {
      return;
    }

    await Future<void>.delayed(Duration.zero);
    if (!mounted || !context.mounted) {
      return;
    }

    final beforeCluster = serviceRegionForCountryCode(current.countryCode);
    final snapshot = LocaleRegionState(
      locale: current.locale,
      countryCode: current.countryCode,
      localeGateCompleted: current.localeGateCompleted,
    );
    final clusterSwitch = beforeCluster != serviceRegionForCountryCode(newCode);
    final loggedIn = ref.read(authProvider).isLoggedIn;

    if (clusterSwitch && loggedIn) {
      localeDialogNavigator?.pop();
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !context.mounted) {
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.serverClusterSwitchTitle),
          content: Text(l10n.serverClusterSwitchMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted || !context.mounted) {
        return;
      }
      await ref.read(authProvider.notifier).clearAuth();
      await store.restoreState(snapshot);
      if (!mounted || !context.mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      return;
    }

    await store.setCountryCode(newCode);
  }
}

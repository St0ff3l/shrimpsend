import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../device_id.dart';
import '../logger.dart';
import '../providers/app_mode_provider.dart';
import '../providers/device_provider.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';
import '../ui/platform_icon.dart';
import '../utils/auth_route_guard.dart';
import '../utils/toast.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/devices/device_id_chip.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  String? _hoveredMyDeviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ensureLoggedInForRoute(context, ref)) return;
      ref.read(cloudDeviceRosterProvider.notifier).refreshSnapshot();
    });
  }

  void _refresh() {
    ref.read(cloudDeviceRosterProvider.notifier).refreshSnapshot();
  }

  bool _useLongPressForDeviceActions(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.sizeOf(context).shortestSide < 600;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _removeOtherDevice(DeviceDto d) async {
    final l10n = AppLocalizations.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.devicesRemoveTitle,
      content: l10n.devicesRemoveBody,
      confirmLabel: l10n.devicesRemoveConfirm,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!ok || !mounted) return;
    try {
      await deleteDevice(d.deviceId);
      if (!mounted) return;
      ref.read(cloudDeviceRosterProvider.notifier).applyRemove(d.deviceId);
      AppToast.show(context, message: l10n.devicesRemovedToast);
      Analytics.track(AnalyticsEvents.deviceRemove, {'result': 'success'});
    } catch (e) {
      logDevices.warning('remove device failed: $e');
      Analytics.track(AnalyticsEvents.deviceRemove, {'result': 'fail'});
      if (mounted) {
        AppToast.show(
          context,
          message: AppLocalizations.of(context).devicesRemoveFailed('$e'),
        );
      }
    }
  }

  Future<void> _renameDevice(DeviceDto d, String currentDeviceId) async {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final outerL10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: d.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
          titlePadding: AppDialog.titlePadding,
          contentPadding: AppDialog.confirmContentPadding,
          actionsPadding: AppDialog.actionsPadding,
          title: Row(
            children: [
              Expanded(
                child: Text(loc.devicesRenameTitle,
                    style: theme.textTheme.titleMedium),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  foregroundColor: colors.textTertiary,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(hintText: loc.devicesNameHint),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(loc.cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, nameController.text.trim()),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(loc.commonSave),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      await updateDevice(d.deviceId, name: result);
      if (d.deviceId == currentDeviceId) await setDeviceName(result);
      if (mounted) {
        AppToast.show(context, message: outerL10n.devicesSavedToast);
        _refresh();
      }
    } catch (e) {
      logDevices.warning('rename failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message:
              AppLocalizations.of(context).devicesSaveFailed('$e'),
        );
      }
    }
  }

  void _showMyDeviceActionsSheet(DeviceDto d, String currentId) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final loc = AppLocalizations.of(context);
    final isCurrent = d.deviceId == currentId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.pencil, color: theme.colorScheme.primary),
                title: Text(loc.devicesRenameMenu),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameDevice(d, currentId);
                },
              ),
              if (!isCurrent)
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: colors.danger),
                  title: Text(loc.devicesRemoveMenu,
                      style: TextStyle(color: colors.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeOtherDevice(d);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHoverActions(
    DeviceDto d,
    String currentId,
    ThemeData theme,
    AppThemeColors colors,
  ) {
    final isCurrent = d.deviceId == currentId;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _deviceActionIconBtn(
            LucideIcons.pencil,
            theme.colorScheme.primary,
            () => _renameDevice(d, currentId),
          ),
          if (!isCurrent)
            _deviceActionIconBtn(
              LucideIcons.trash2,
              colors.danger,
              () => _removeOtherDevice(d),
            ),
        ],
      ),
    );
  }

  Widget _deviceActionIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final isOffline = ref.watch(effectiveOfflineModeProvider);
    final myDevicesAsync = ref.watch(myDevicesAsyncProvider);

    if (isOffline) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.devicesTitle),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cloudOff, size: 48, color: colors.textTertiary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.devicesOfflinePrompt,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: myDevicesAsync.when(
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.devicesTitle),
              Text(
                l10n.devicesBoundCount(list.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.devicesTitle),
              Text(
                l10n.devicesSyncing,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.devicesTitle),
              Text(
                l10n.devicesSubtitleLoadFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.danger,
                ),
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: l10n.devicesTooltipRefresh,
            onPressed: _refresh,
          ),
        ],
      ),
      body: myDevicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cloudOff, size: 40, color: colors.textTertiary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.devicesLoadFailedDetail('$e'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
        data: (myDevices) => FutureBuilder<String>(
          future: getOrCreateDeviceId(),
          builder: (ctx, idSnap) {
            final currentId = idSnap.data ?? '';
            final useLongPress = _useLongPressForDeviceActions(context);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.contentMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (myDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        child: Text(
                          l10n.devicesEmptyList,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      )
                    else
                      ...myDevices.map(
                        (d) => _buildMyDeviceCard(
                          d,
                          currentId,
                          theme,
                          colors,
                          useLongPress,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMyDeviceCard(
    DeviceDto d,
    String currentId,
    ThemeData theme,
    AppThemeColors colors,
    bool useLongPress,
  ) {
    final isCurrent = d.deviceId == currentId;
    final isHovered = _hoveredMyDeviceId == d.deviceId;

    final listTile = ListTile(
      contentPadding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        useLongPress ? AppSpacing.md : 96,
        AppSpacing.xxs,
      ),
      leading: Container(
        width: AppSize.settingsIcon,
        height: AppSize.settingsIcon,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: AppRadius.small,
        ),
        child: Icon(
          platformIcon(d.platform),
          color: platformColor(d.platform, theme.brightness),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              d.name,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DeviceManagementDisplayCodeChip(displayCode: d.displayCode, colors: colors),
        ],
      ),
      subtitle: isCurrent
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildBadge(
                    label: AppLocalizations.of(context).devicesCurrentDeviceBadge,
                    background: colors.accentSoft,
                    foreground: theme.colorScheme.primary,
                  ),
                ],
              ),
            )
          : null,
    );

    Widget cardChild;
    if (useLongPress) {
      cardChild = InkWell(
        onLongPress: () => _showMyDeviceActionsSheet(d, currentId),
        borderRadius: AppRadius.medium,
        child: listTile,
      );
    } else {
      cardChild = MouseRegion(
        onEnter: (_) => setState(() => _hoveredMyDeviceId = d.deviceId),
        onExit: (_) {
          if (_hoveredMyDeviceId == d.deviceId) {
            setState(() => _hoveredMyDeviceId = null);
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            listTile,
            if (isHovered)
              Positioned(
                right: AppSpacing.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildDesktopHoverActions(
                    d,
                    currentId,
                    theme,
                    colors,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: cardChild,
    );
  }

  Widget _buildBadge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.small,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../network/connection_resolution.dart';
import '../../providers/device_provider.dart';
import '../../ui/app_ui.dart';

Future<SendMode?> showLinkRoutesDialog({
  required BuildContext context,
  required String peerLabel,
  required SendMode currentMode,
  required SendMode targetMode,
  required List<ConnectionCandidate> candidates,
}) {
  return showDialog<SendMode>(
    context: context,
    builder: (ctx) {
      return _LinkRoutesDialog(
        peerLabel: peerLabel,
        currentMode: currentMode,
        targetMode: targetMode,
        candidates: candidates,
      );
    },
  );
}

Future<SendMode?> showLinkRoutesPickerDialog({
  required BuildContext context,
  required String peerLabel,
  required SendMode currentMode,
  required List<ConnectionCandidate> candidates,
}) {
  return showDialog<SendMode>(
    context: context,
    builder: (_) {
      return _LinkRoutesPickerDialog(
        peerLabel: peerLabel,
        currentMode: currentMode,
        candidates: candidates,
      );
    },
  );
}

class _LinkRoutesDialog extends StatelessWidget {
  const _LinkRoutesDialog({
    required this.peerLabel,
    required this.currentMode,
    required this.targetMode,
    required this.candidates,
  });

  final String peerLabel;
  final SendMode currentMode;
  final SendMode targetMode;
  final List<ConnectionCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final routes = _buildDisplayRoutes(
      candidates,
      currentMode,
      targetMode,
      l10n.linkRoutesWaitingResult,
    );
    final isReselect = currentMode == targetMode;
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.52).clamp(
      280.0,
      460.0,
    );

    return AlertDialog(
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.contentPadding,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isReselect ? l10n.linkRoutesTitleRetest : l10n.linkRoutesTitleSwitch,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.linkRoutesPeerSession(peerLabel),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReselect
                  ? l10n.linkRoutesBodyRetest
                  : l10n.linkRoutesBodySwitch(
                      connectionModeLabel(targetMode, l10n: l10n),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.separated(
                itemCount: routes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final speed = _estimateSpeed(l10n, route.mode);
                  final isCurrent = route.mode == currentMode;
                  final isTarget = route.mode == targetMode;
                  final cardColor = isTarget
                      ? colors.accentSoft
                      : colors.surfaceMuted.withValues(alpha: 0.7);
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: AppRadius.small,
                      border: Border.all(
                        color: isTarget
                            ? theme.colorScheme.primary.withValues(alpha: 0.45)
                            : colors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              connectionModeLabel(route.mode, l10n: l10n),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _TagChip(
                              text: route.available
                                  ? l10n.linkRoutesTagAvailable
                                  : l10n.linkRoutesTagUnavailable,
                              foreground: route.available
                                  ? colors.success
                                  : colors.danger,
                              background: route.available
                                  ? colors.successSurface
                                  : colors.dangerSurface,
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: AppSpacing.xs),
                              _TagChip(
                                text: l10n.linkRoutesTagCurrent,
                                foreground: colors.textSecondary,
                                background: colors.surface,
                              ),
                            ],
                            if (isTarget) ...[
                              const SizedBox(width: AppSpacing.xs),
                              _TagChip(
                                text: l10n.linkRoutesTagTarget,
                                foreground: theme.colorScheme.primary,
                                background: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          l10n.linkRoutesSpeedLine(speed.tier, speed.desc),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          route.reason.isEmpty
                              ? l10n.linkRoutesWaitingResult
                              : route.reason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(targetMode),
          child: Text(
            isReselect ? l10n.linkRoutesRetest : l10n.linkRoutesSwitchAndDetect,
          ),
        ),
      ],
    );
  }
}

class _LinkRoutesPickerDialog extends StatefulWidget {
  const _LinkRoutesPickerDialog({
    required this.peerLabel,
    required this.currentMode,
    required this.candidates,
  });

  final String peerLabel;
  final SendMode currentMode;
  final List<ConnectionCandidate> candidates;

  @override
  State<_LinkRoutesPickerDialog> createState() =>
      _LinkRoutesPickerDialogState();
}

class _LinkRoutesPickerDialogState extends State<_LinkRoutesPickerDialog> {
  late SendMode _selectedMode = widget.currentMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.56).clamp(
      320.0,
      520.0,
    );
    final l10n = AppLocalizations.of(context);
    final routes = _buildDisplayRoutes(
      widget.candidates,
      widget.currentMode,
      _selectedMode,
      l10n.linkRoutesWaitingResult,
    );
    return AlertDialog(
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.contentPadding,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.linkRoutesPickerTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.linkRoutesPeerSession(widget.peerLabel),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.linkRoutesPickerHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.separated(
                itemCount: routes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final speed = _estimateSpeed(l10n, route.mode);
                  final isCurrent = route.mode == widget.currentMode;
                  final isSelected = route.mode == _selectedMode;
                  final cardColor = isSelected
                      ? colors.accentSoft
                      : colors.surfaceMuted.withValues(alpha: 0.7);
                  return InkWell(
                    borderRadius: AppRadius.small,
                    onTap: () => setState(() => _selectedMode = route.mode),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: AppRadius.small,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.45,
                                )
                              : colors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : colors.textTertiary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                connectionModeLabel(route.mode, l10n: l10n),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _TagChip(
                                text: route.available
                                    ? l10n.linkRoutesTagAvailable
                                    : l10n.linkRoutesTagUnavailable,
                                foreground: route.available
                                    ? colors.success
                                    : colors.danger,
                                background: route.available
                                    ? colors.successSurface
                                    : colors.dangerSurface,
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: AppSpacing.xs),
                                _TagChip(
                                  text: l10n.linkRoutesTagCurrent,
                                  foreground: colors.textSecondary,
                                  background: colors.surface,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            l10n.linkRoutesSpeedLine(speed.tier, speed.desc),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            route.reason.isEmpty
                                ? l10n.linkRoutesWaitingResult
                                : route.reason,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedMode),
          child: Text(l10n.linkRoutesSwitchAndDetect),
        ),
      ],
    );
  }
}

class _RouteViewData {
  const _RouteViewData({
    required this.mode,
    required this.available,
    required this.reason,
  });

  final SendMode mode;
  final bool available;
  final String reason;
}

class _SpeedEstimate {
  const _SpeedEstimate(this.tier, this.desc);

  final String tier;
  final String desc;
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground, fontSize: 10),
      ),
    );
  }
}

List<_RouteViewData> _buildDisplayRoutes(
  List<ConnectionCandidate> raw,
  SendMode currentMode,
  SendMode targetMode,
  String waitingReason,
) {
  final byMode = <SendMode, _RouteViewData>{};
  for (final c in raw) {
    byMode.putIfAbsent(
      c.mode,
      () => _RouteViewData(
        mode: c.mode,
        available: c.available,
        reason: c.reason,
      ),
    );
  }

  void ensureMode(SendMode mode) {
    byMode.putIfAbsent(
      mode,
      () => _RouteViewData(mode: mode, available: false, reason: waitingReason),
    );
  }

  ensureMode(currentMode);
  ensureMode(targetMode);

  final list = byMode.values.toList();
  list.sort((a, b) {
    if (a.mode == targetMode) return -1;
    if (b.mode == targetMode) return 1;
    if (a.mode == currentMode) return -1;
    if (b.mode == currentMode) return 1;
    if (a.available == b.available) return 0;
    return a.available ? -1 : 1;
  });
  return list;
}

_SpeedEstimate _estimateSpeed(AppLocalizations l10n, SendMode mode) {
  switch (mode) {
    case SendMode.nearby:
      return _SpeedEstimate(l10n.linkSpeedNearbyTier, l10n.linkSpeedNearbyDesc);
    case SendMode.lan:
      return _SpeedEstimate(l10n.linkSpeedLanTier, l10n.linkSpeedLanDesc);
    case SendMode.webrtc:
      return _SpeedEstimate(l10n.linkSpeedWebrtcTier, l10n.linkSpeedWebrtcDesc);
    case SendMode.s3:
      return _SpeedEstimate(l10n.linkSpeedS3Tier, l10n.linkSpeedS3Desc);
  }
}

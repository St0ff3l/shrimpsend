import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/file_store.dart';
import '../ui/app_ui.dart';
import '../utils/received_file_actions.dart';

class ReceivedFileActionBar extends StatelessWidget {
  final ReceivedFileInfo file;
  final bool forceText;
  final bool useDarkChrome;
  final ReceivedFilePreviewCallbacks? callbacks;

  const ReceivedFileActionBar({
    super.key,
    required this.file,
    this.forceText = false,
    this.useDarkChrome = false,
    this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final actions = buildReceivedFileActions(
      file: file,
      l10n: l10n,
      forceText: forceText,
      callbacks: callbacks,
    );
    if (actions.isEmpty) return const SizedBox.shrink();

    final iconColor = useDarkChrome ? Colors.white : colors.textSecondary;
    final dangerColor = useDarkChrome ? const Color(0xFFFF6B6B) : colors.danger;

    final decoration = useDarkChrome
        ? BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          )
        : BoxDecoration(
            color: Color.alphaBlend(
              colors.surface.withValues(alpha: 0.94),
              theme.scaffoldBackgroundColor,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.border.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        height: 52,
        decoration: decoration,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions) ...[
                Tooltip(
                  message: action.tooltip,
                  child: IconButton(
                    icon: Icon(
                      action.icon,
                      size: AppSize.appBarActionIcon,
                      color: action.isDanger ? dangerColor : iconColor,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: action.onTap == null
                        ? null
                        : () => action.onTap!(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

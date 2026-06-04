import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/app_ui.dart';
import 'chat_theme_helpers.dart';

class ChatInitErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ChatColors colors;

  const ChatInitErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatDropOverlay extends StatelessWidget {
  final ChatColors colors;

  const ChatDropOverlay({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: colors.surface.withValues(alpha: 0.8),
        child: Center(
          child: Text(
            AppLocalizations.of(context).chatDropReleaseToAdd,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ),
      ),
    );
  }
}

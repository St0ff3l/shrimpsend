import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide ChatColors;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../color_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/app_ui.dart';
import '../../utils/file_utils.dart';
import '../file_icon_widget.dart';
import 'chat_theme_helpers.dart';
import 'linkable_message_text.dart';
import 'transfer_channel_badge.dart';

class PlainTextBubble extends StatelessWidget {
  final ChatColors colors;
  final TextMessage message;
  final bool isSentByMe;

  const PlainTextBubble({
    super.key,
    required this.colors,
    required this.message,
    required this.isSentByMe,
  });

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isSentByMe ? colors.bubbleSent : colors.bubbleReceived;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onBubble(isSentByMe),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: AppRadius.medium,
      ),
      child: LinkableMessageText(
        text: message.text,
        baseStyle: textStyle,
        linkColor: colors.bubbleLink(isSentByMe),
        selectable: _isDesktop,
      ),
    );
  }
}

class FailedTextBubble extends StatelessWidget {
  final ChatColors colors;
  final TextMessage message;
  final int index;
  final VoidCallback onRetry;

  const FailedTextBubble({
    super.key,
    required this.colors,
    required this.message,
    required this.index,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onBubbleSent,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.bubbleSent,
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: colors.danger.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: LinkableMessageText(
              text: message.text,
              baseStyle: textStyle,
              linkColor: colors.bubbleLink(true),
              selectable: PlainTextBubble._isDesktop,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Icon(
              LucideIcons.refreshCw,
              size: 18,
              color: colors.bubbleAccent(true, colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class TransferProgressBubble extends StatelessWidget {
  final ChatColors colors;
  final String fileName;
  final double? progress;
  final bool isUploading;
  final String? statusText;
  final String? speed;
  final bool canCancel;
  final VoidCallback? onCancel;
  final bool isSentByMe;
  final String? transferLabel;
  final String? transferType;
  final int? fileSize;
  final double? speedBytesPerSecond;
  final Duration? elapsed;

  const TransferProgressBubble({
    super.key,
    required this.colors,
    required this.fileName,
    required this.progress,
    required this.isUploading,
    this.statusText,
    this.speed,
    this.canCancel = false,
    this.onCancel,
    required this.isSentByMe,
    this.transferLabel,
    this.transferType,
    this.fileSize,
    this.speedBytesPerSecond,
    this.elapsed,
  });

  String? _formatEta(AppLocalizations l10n) {
    final total = fileSize;
    final p = progress;
    if (total == null || total <= 0 || p == null) return null;
    final remainingBytes = total * (1.0 - p);
    if (remainingBytes <= 0) return null;

    double? bps = speedBytesPerSecond;
    if (bps == null || bps <= 0) {
      final el = elapsed;
      if (el != null) {
        final elapsedSec = el.inMilliseconds / 1000.0;
        if (elapsedSec >= 0.3 && p >= 0.005) {
          bps = (total * p) / elapsedSec;
        }
      }
    }
    if (bps == null || bps <= 0) return null;

    final sec = (remainingBytes / bps).round();
    if (sec < 0 || sec > 86400 * 7) return null;
    if (sec < 60) return l10n.chatTransferEtaSecondsRemaining(sec);
    final m = sec ~/ 60;
    final s = sec % 60;
    return l10n.chatTransferEtaMinutesSecondsRemaining(m, s);
  }

  String _buildSubLine(AppLocalizations l10n) {
    final parts = <String>[];
    if (statusText != null) {
      parts.add(statusText!);
    } else {
      parts.add(
        isUploading
            ? l10n.chatTransferProgressSending
            : l10n.chatTransferProgressReceiving,
      );
    }
    if (transferType == null &&
        transferLabel != null &&
        transferLabel!.isNotEmpty) {
      parts.add(transferLabel!);
    }
    final showSizeHere = !(progress != null &&
        fileSize != null &&
        fileSize! > 0);
    final sizeStr = formatFileSize(fileSize);
    if (showSizeHere && sizeStr.isNotEmpty) parts.add(sizeStr);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pct = progress != null ? (progress! * 100).round() : null;
    final accent = isUploading ? colors.upload : colors.download;
    final accentOnBubble = colors.bubbleAccent(isSentByMe, accent);
    final subLine = _buildSubLine(l10n);
    final theme = Theme.of(context);
    final showByteRow =
        progress != null && fileSize != null && fileSize! > 0;
    final doneBytes =
        showByteRow ? (fileSize! * progress!).round() : null;
    final eta = _formatEta(l10n);
    final muted = colors.bubbleMuted(isSentByMe);

    final category = getFileCategory(fileName);
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSentByMe ? colors.bubbleSent : colors.bubbleReceived,
        borderRadius: AppRadius.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FileIconWidget(category: category, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onBubble(isSentByMe),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (transferType != null) ...[
                      const SizedBox(width: 6),
                      TransferChannelBadge(
                        transferType: transferType,
                        liftOnTintedSentBubble: isSentByMe,
                      ),
                    ],
                    if (!showByteRow && pct != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: accentOnBubble,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (canCancel) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onCancel,
                        child: Icon(
                          LucideIcons.x,
                          size: 16,
                          color: colors.bubbleAccent(isSentByMe, colors.danger),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      isUploading ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                      size: 12,
                      color: accentOnBubble,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        subLine,
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.bubbleTrack(isSentByMe),
                    valueColor: AlwaysStoppedAnimation<Color>(accentOnBubble),
                    minHeight: 6,
                  ),
                ),
                if (showByteRow ||
                    (speed != null && speed!.isNotEmpty) ||
                    eta != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: showByteRow && doneBytes != null
                            ? Text(
                                '${formatFileSize(doneBytes)} / ${formatFileSize(fileSize)}',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if ((speed != null && speed!.isNotEmpty) || eta != null)
                        Text(
                          [
                            if (speed != null && speed!.isNotEmpty) speed!,
                            if (eta != null) eta,
                          ].join(' '),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TransferStatusBubble extends StatelessWidget {
  final ChatColors colors;
  final String text;
  final Color color;
  final IconData icon;
  final bool isSentByMe;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchToS3;
  final String? subtitle;
  final String? transferType;

  const TransferStatusBubble({
    super.key,
    required this.colors,
    required this.text,
    required this.color,
    required this.icon,
    required this.isSentByMe,
    this.onRetry,
    this.onSwitchToS3,
    this.subtitle,
    this.transferType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSentByMe ? colors.bubbleSent : colors.bubbleReceived,
        borderRadius: AppRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(color: color),
                      ),
                    ),
                    if (transferType != null) ...[
                      const SizedBox(width: 6),
                      TransferChannelBadge(
                        transferType: transferType,
                        liftOnTintedSentBubble: isSentByMe,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: colors.bubbleMuted(isSentByMe),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null || onSwitchToS3 != null) ...[
            const SizedBox(width: 8),
            if (onRetry != null)
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '重试',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (onSwitchToS3 != null) ...[
              if (onRetry != null) const SizedBox(width: 6),
              GestureDetector(
                onTap: onSwitchToS3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColorTheme.s3Color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '切换到S3',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../color_theme_store.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import 'chat/transfer_channel_badge.dart';
import 'file_icon_widget.dart';

class FileCardBubble extends StatelessWidget {
  final String fileName;
  final int? size;
  final String? transferType;
  final bool hasDownload;
  final bool isSentByMe;
  final String? filePath;

  const FileCardBubble({
    super.key,
    required this.fileName,
    this.size,
    this.transferType,
    this.hasDownload = false,
    required this.isSentByMe,
    this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);
    final colorTheme = ColorThemeStoreScope.of(context).notifier.value;

    final bubbleColor = isSentByMe
        ? colorTheme.bubbleSent(brightness)
        : colorTheme.bubbleReceived(brightness);
    final onBubble = isSentByMe
        ? colorTheme.onBubbleSent(brightness)
        : colorTheme.onBubbleReceived(brightness);
    final muted = colorTheme.onBubbleMuted(brightness, isSentByMe: isSentByMe);
    final accent = colorTheme.bubbleAccent(
      brightness,
      isSentByMe: isSentByMe,
      accent: theme.colorScheme.primary,
    );
    final sizeStr = formatFileSize(size);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: AppRadius.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FileIconWidget(
            category: getFileCategory(fileName),
            size: 40,
            filePath: filePath,
          ),
          const SizedBox(width: 12),
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
                          color: onBubble,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
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
                  ],
                ),
                if (sizeStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sizeStr,
                    style: TextStyle(color: muted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (hasDownload)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                LucideIcons.download,
                size: 22,
                color: accent,
              ),
            ),
        ],
      ),
    );
  }
}

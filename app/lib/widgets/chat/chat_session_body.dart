import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide ChatColors;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/device_provider.dart';
import 'chat_theme_helpers.dart';
import 'transfer_mode_bar.dart';

class ChatSessionBody extends StatelessWidget {
  final VoidCallback? onRefresh;
  final Future<void> Function(SendMode mode)? onModeSelected;
  final String currentUserId;
  final String deviceName;
  final InMemoryChatController chatController;
  final Future<void> Function(String text) onMessageSend;
  final Future<void> Function() onAttachmentTap;
  final void Function(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  })
  onMessageTap;
  final Widget Function(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  })
  textMessageBuilder;
  final VoidCallback onChatTap;
  final ScrollController scrollController;
  final Future<void> Function() onEndReached;
  final Widget Function(BuildContext context) composerBuilder;
  final ChatColors colors;
  final bool isDark;

  const ChatSessionBody({
    super.key,
    this.onRefresh,
    this.onModeSelected,
    required this.currentUserId,
    required this.deviceName,
    required this.chatController,
    required this.onMessageSend,
    required this.onAttachmentTap,
    required this.onMessageTap,
    required this.textMessageBuilder,
    required this.onChatTap,
    required this.scrollController,
    required this.onEndReached,
    required this.composerBuilder,
    required this.colors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConnectionBarSection(
          onRefresh: onRefresh,
          onModeSelected: onModeSelected,
        ),
        Expanded(
          child: Chat(
            currentUserId: currentUserId,
            resolveUser: (id) async => User(
              id: id,
              name: id == currentUserId
                  ? deviceName
                  : (id.length > 12 ? '${id.substring(0, 12)}…' : id),
            ),
            chatController: chatController,
            onMessageSend: onMessageSend,
            onAttachmentTap: onAttachmentTap,
            onMessageTap: onMessageTap,
            theme: isDark ? ChatTheme.dark() : ChatTheme.light(),
            backgroundColor: colors.surface,
            builders: Builders(
              textMessageBuilder: textMessageBuilder,
              chatAnimatedListBuilder: (context, itemBuilder) =>
                  GestureDetector(
                    onTap: onChatTap,
                    behavior: HitTestBehavior.translucent,
                    child: ChatAnimatedListReversed(
                      itemBuilder: itemBuilder,
                      scrollController: scrollController,
                      onEndReached: onEndReached,
                      shouldScrollToEndWhenSendingMessage: false,
                    ),
                  ),
              composerBuilder: composerBuilder,
            ),
          ),
        ),
      ],
    );
  }
}

/// Watches connection state in isolation so probe-progress rebuilds stay
/// inside this subtree and never bubble up to [ChatSessionBody] or [ChatScreen].
class _ConnectionBarSection extends ConsumerWidget {
  const _ConnectionBarSection({
    required this.onRefresh,
    required this.onModeSelected,
  });

  final VoidCallback? onRefresh;
  final Future<void> Function(SendMode mode)? onModeSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TransferModeBar(
      onRefresh: onRefresh,
      onModeSelected: onModeSelected,
    );
  }
}

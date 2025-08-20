import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/utils/date_utils.dart' as app_date_utils;

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final isMe = message.senderId == userProvider.currentUser?.id;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          message.senderName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMessageContent(context, isMe),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                app_date_utils.DateUtils.formatMessageTime(
                                  message.timestamp,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  message.isRead ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: message.isRead
                                      ? Colors.blue[300]
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    userProvider.currentUser?.username.isNotEmpty == true
                        ? userProvider.currentUser!.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isMe) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isMe
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 200,
                  maxHeight: 200,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 200,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isMe
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );

      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file,
              size: 20,
              color: isMe
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'File',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isMe
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      case MessageType.system:
        return Text(
          message.content,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }
}

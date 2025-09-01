import 'package:flutter/material.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/utils/date_utils.dart' as app_date_utils;

class ChatRoomTile extends StatelessWidget {
  final ChatRoom chatRoom;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ChatRoomTile({
    super.key,
    required this.chatRoom,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar - WhatsApp style
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    chatRoom.name.isNotEmpty
                        ? chatRoom.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chatRoom.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chatRoom.lastMessage != null)
                            Text(
                              app_date_utils.DateUtils.formatChatRoomTime(
                                chatRoom.lastMessage!.timestamp,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: chatRoom.lastMessage != null
                                ? Text(
                                    chatRoom.lastMessage!.content,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                          fontSize: 14,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    'No messages yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                          ),
                          if (chatRoom.hasUnreadMessages)
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Options menu
                if (onDelete != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteDialog(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete chat',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
            'Are you sure you want to delete this chat? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDelete!();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

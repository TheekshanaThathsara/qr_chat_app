import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/utils/date_utils.dart' as app_date_utils;

class ChatRoomTile extends StatelessWidget {
  final ChatRoom chatRoom;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onClear;
  final VoidCallback? onPinToggle;

  const ChatRoomTile({
    super.key,
    required this.chatRoom,
    required this.onTap,
  this.onDelete,
  this.onClear,
  this.onPinToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Determine chat title for private chats
        String chatTitle = chatRoom.name;
        if (chatRoom.isPrivate && userProvider.currentUser != null) {
          final otherParticipant = chatRoom.participants.firstWhere(
            (participant) => participant.id != userProvider.currentUser!.id,
            orElse: () => chatRoom.participants.first,
          );
          chatTitle = otherParticipant.username.isNotEmpty
              ? otherParticipant.username
              : 'Private Chat';
        }

        // Format last message with sender info
        String lastMessageText = 'No messages yet';
        if (chatRoom.lastMessage != null) {
          final isMe =
              chatRoom.lastMessage!.senderId == userProvider.currentUser?.id;
          final messageContent = chatRoom.lastMessage!.content.isNotEmpty
              ? chatRoom.lastMessage!.content
              : 'Media';

          if (chatRoom.isPrivate) {
            // For private chats, show "You: message" or just "message"
            lastMessageText = isMe ? 'You: $messageContent' : messageContent;
          } else {
            // For group chats, show "Sender: message"
            lastMessageText = isMe
                ? 'You: $messageContent'
                : '${chatRoom.lastMessage!.senderName}: $messageContent';
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Avatar - WhatsApp style
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        chatTitle.isNotEmpty ? chatTitle[0].toUpperCase() : '?',
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
                                  chatTitle,
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
                                child: Text(
                                  lastMessageText,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (chatRoom.participantCount > 2)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${chatRoom.participantCount}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
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
                            onDelete!();
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
      },
    );
  }
}

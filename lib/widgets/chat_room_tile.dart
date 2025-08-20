import 'package:flutter/material.dart';
import 'package:instant_chat_app/models/chat_room.dart';
import 'package:instant_chat_app/utils/date_utils.dart' as app_date_utils;

class ChatRoomTile extends StatelessWidget {
  final ChatRoom chatRoom;
  final VoidCallback onTap;

  const ChatRoomTile({super.key, required this.chatRoom, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            chatRoom.name.isNotEmpty ? chatRoom.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          chatRoom.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chatRoom.lastMessage != null)
              Text(
                chatRoom.lastMessage!.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              )
            else
              Text(
                'No messages yet',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  chatRoom.isPrivate ? Icons.lock : Icons.group,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${chatRoom.participantCount} member${chatRoom.participantCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (chatRoom.lastMessage != null)
              Text(
                app_date_utils.DateUtils.formatChatRoomTime(
                  chatRoom.lastMessage!.timestamp,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            const SizedBox(height: 4),
            if (chatRoom.hasUnreadMessages)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

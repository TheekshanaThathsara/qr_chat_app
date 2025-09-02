import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/models/message.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/utils/date_utils.dart' as app_date_utils;

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Don't render empty messages to prevent blank message display
    if (message.content.trim().isEmpty && message.type != MessageType.system) {
      return const SizedBox.shrink();
    }
    
    // For system messages, also check if content is meaningful
    if (message.type == MessageType.system && message.content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final isMe = message.senderId == userProvider.currentUser?.id;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(context, isMe),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMessageContent(context, isMe),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    app_date_utils.DateUtils.formatMessageTime(
                                      message.timestamp,
                                    ),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      message.isRead
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 16,
                                      color: message.isRead
                                          ? Colors.orange[200]
                                          : Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 200,
                    maxHeight: 200,
                  ),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 50, color: Colors.grey),
                    Text('Image', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message.content,
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                ),
              ),
          ],
        );

      case MessageType.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_file,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.fileName ?? 'File',
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.grey[600],
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

  void _showMessageOptions(BuildContext context, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Message Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(context);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement reply functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reply feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Sent:',
              app_date_utils.DateUtils.formatMessageTime(message.timestamp),
            ),
            if (message.isRead)
              _buildInfoRow(
                'Read:',
                app_date_utils.DateUtils.formatMessageTime(message.timestamp),
              ),
            _buildInfoRow('Type:', message.type.toString().split('.').last),
            _buildInfoRow('Length:', '${message.content.length} characters'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

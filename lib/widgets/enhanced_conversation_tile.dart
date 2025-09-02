import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../theme/app_theme.dart';

class EnhancedConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const EnhancedConversationTile({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final otherUserName = conversation.getOtherUserName(currentUserId);
    final otherUserProfileImage = conversation.getOtherUserProfileImage(currentUserId);
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final hasUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUnread ? AppTheme.primaryColor.withOpacity(0.2) : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: hasUnread 
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: hasUnread ? 8 : 4,
            spreadRadius: hasUnread ? 2 : 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Avatar
                _buildAvatar(otherUserName, otherUserProfileImage, hasUnread),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: _buildContent(otherUserName, hasUnread),
                ),
                
                // Trailing
                _buildTrailing(hasUnread, unreadCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String otherUserName, String? otherUserProfileImage, bool hasUnread) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasUnread 
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : null,
        gradient: hasUnread 
            ? AppTheme.primaryGradient.scale(0.2) 
            : null,
      ),
      child: Container(
        margin: hasUnread ? const EdgeInsets.all(2) : EdgeInsets.zero,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: CircleAvatar(
          radius: hasUnread ? 25 : 28,
          backgroundImage: otherUserProfileImage != null
              ? NetworkImage(otherUserProfileImage)
              : null,
          backgroundColor: hasUnread 
              ? AppTheme.primaryColor 
              : AppTheme.primaryColor.withOpacity(0.7),
          child: otherUserProfileImage == null
              ? Text(
                  otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: hasUnread ? 18 : 16,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildContent(String otherUserName, bool hasUnread) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          otherUserName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        
        // Last message or status
        Row(
          children: [
            if (hasUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                conversation.lastMessage ?? 'No messages yet',
                style: TextStyle(
                  fontSize: 14,
                  color: hasUnread 
                      ? AppTheme.textPrimaryColor 
                      : AppTheme.textSecondaryColor,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailing(bool hasUnread, int unreadCount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Time
        if (conversation.lastMessageTime != null)
          Text(
            _formatTime(conversation.lastMessageTime!),
            style: TextStyle(
              color: hasUnread 
                  ? AppTheme.primaryColor 
                  : AppTheme.textSecondaryColor,
              fontSize: 12,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        
        // Unread badge
        if (hasUnread) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

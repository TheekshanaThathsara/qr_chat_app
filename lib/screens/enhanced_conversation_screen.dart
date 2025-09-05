import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../providers/conversation_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'user_details_screen.dart';

class EnhancedConversationScreen extends StatefulWidget {
  final Conversation conversation;
  final String currentUserId;

  const EnhancedConversationScreen({
    Key? key,
    required this.conversation,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<EnhancedConversationScreen> createState() => _EnhancedConversationScreenState();
}

class _EnhancedConversationScreenState extends State<EnhancedConversationScreen> 
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  int _previousMessageCount = 0;
  Message? _replyToMessage;
  
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonAnimation;

  @override
  void initState() {
    super.initState();
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.easeInOut,
    ));
    
    _messageController.addListener(_onMessageChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _sendButtonController.dispose();
    
    // Clear current conversation when leaving screen
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    conversationProvider.clearCurrentConversation();
    super.dispose();
  }

  void _onMessageChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText) {
      _sendButtonController.forward();
    } else {
      _sendButtonController.reverse();
    }
  }

  void _loadMessages() {
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    conversationProvider.loadMessages(widget.conversation.id, currentUserId: widget.currentUserId);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    // Clear the input field immediately
    _messageController.clear();
    _sendButtonController.reverse();

    // Send the message with reply info if replying
    if (_replyToMessage != null) {
      await conversationProvider.sendMessage(
        widget.conversation.id,
        currentUser.id,
        currentUser.username,
        text,
        replyToMessageId: _replyToMessage!.id,
        replyToContent: _replyToMessage!.content,
        replyToSenderName: _replyToMessage!.senderName,
      );
      // Clear reply after sending
      _clearReply();
    } else {
      await conversationProvider.sendMessage(
        widget.conversation.id,
        currentUser.id,
        currentUser.username,
        text,
      );
    }

    // Scroll to bottom
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMessageActions(Message message) {
    print('Showing message actions for: ${message.content}');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.reply,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _setReplyMessage(message);
                },
              ),
              if (message.senderId == widget.currentUserId)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _setReplyMessage(Message message) {
    setState(() {
      _replyToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _deleteMessage(Message message) async {
    try {
      final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
      await conversationProvider.deleteMessage(message.id, widget.currentUserId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message deleted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting message: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.conversation.getOtherUserName(widget.currentUserId);
    final otherUserProfileImage = widget.conversation.getOtherUserProfileImage(widget.currentUserId);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(otherUserName, otherUserProfileImage),
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(String otherUserName, String? otherUserProfileImage) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              
              // Profile section
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    print('🔥 Profile section tapped!');
                    print('🔥 Conversation ID: ${widget.conversation.id}');
                    print('🔥 Current User ID: ${widget.currentUserId}');
                    print('🔥 Other User Name: $otherUserName');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsScreen(
                          conversation: widget.conversation,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                    ).then((result) {
                      print('🔥 UserDetailsScreen closed with result: $result');
                    }).catchError((error) {
                      print('🔥 UserDetailsScreen navigation error: $error');
                    });
                  },
                  child: Row(
                    children: [
                      Hero(
                        tag: 'profile_${widget.conversation.getOtherUserId(widget.currentUserId)}',
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: otherUserProfileImage != null
                                ? NetworkImage(otherUserProfileImage)
                                : null,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: otherUserProfileImage == null
                                ? Text(
                                    otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otherUserName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Tap to view profile',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // More options
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'clear_chat':
                      _showClearChatDialog();
                      break;
                    case 'block_user':
                      _showBlockUserDialog();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'clear_chat', child: Text('Clear Chat')),
                  PopupMenuItem(value: 'block_user', child: Text('Block User')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return Consumer<ConversationProvider>(
      builder: (context, conversationProvider, child) {
        final messages = conversationProvider.currentMessages;
        
        if (conversationProvider.isLoading && messages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        // Auto-scroll to bottom when new messages arrive
        if (messages.length > _previousMessageCount) {
          _previousMessageCount = messages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == widget.currentUserId;
            final showAvatar = _shouldShowAvatar(messages, index, isMe);
            
            // Check if this message has replies
            final replies = messages.where((m) => m.replyToMessageId == message.id).toList();
            
            return _buildMessageWithReplies(message, replies, isMe, showAvatar, messages);
          },
        );
      },
    );
  }

  bool _shouldShowAvatar(List<Message> messages, int index, bool isMe) {
    if (isMe) return false; // Don't show avatar for own messages
    
    // Show avatar if it's the first message or sender changed
    if (index == 0) return true;
    
    final previousMessage = messages[index - 1];
    return previousMessage.senderId != messages[index].senderId;
  }

  Widget _buildMessageWithReplies(Message message, List<Message> replies, bool isMe, bool showAvatar, List<Message> allMessages) {
    // Skip messages that are replies to other messages (they'll be shown with their parent)
    if (message.replyToMessageId != null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Original message
        _buildMessageBubble(message, isMe, showAvatar),
        
        // Show replies right after the original message
        ...replies.map((reply) {
          final replyIsMe = reply.senderId == widget.currentUserId;
          final replyShowAvatar = _shouldShowAvatarForReply(reply, replyIsMe);
          return Container(
            margin: EdgeInsets.only(
              left: isMe ? 0 : 40, // Indent replies for other users
              right: isMe ? 40 : 0, // Indent replies for own messages
              top: 4,
            ),
            child: Row(
              children: [
                if (!isMe) ...[
                  // Connection line for other user's message
                  Container(
                    width: 20,
                    height: 2,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
                Expanded(
                  child: _buildReplyBubble(reply, replyIsMe, replyShowAvatar),
                ),
                if (isMe) ...[
                  // Connection line for own message
                  Container(
                    width: 20,
                    height: 2,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  bool _shouldShowAvatarForReply(Message reply, bool isMe) {
    return !isMe; // Show avatar for replies from other users
  }

  Widget _buildReplyBubble(Message message, bool isMe, bool showAvatar) {
    final otherUserName = widget.conversation.getOtherUserName(widget.currentUserId);
    final otherUserProfileImage = widget.conversation.getOtherUserProfileImage(widget.currentUserId);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Other user avatar for replies
            Container(
              width: 24, // Smaller avatar for replies
              height: 24,
              margin: const EdgeInsets.only(right: 8, bottom: 8),
              child: showAvatar
                  ? CircleAvatar(
                      radius: 12,
                      backgroundImage: otherUserProfileImage != null
                          ? NetworkImage(otherUserProfileImage)
                          : null,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.7),
                      child: otherUserProfileImage == null
                          ? Text(
                              otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    )
                  : const SizedBox(width: 24, height: 24),
            ),
          ],
          
          // Reply bubble (smaller and with different styling)
          Flexible(
            child: GestureDetector(
              onTap: () {
                print('Tap detected for reply: ${message.content}');
              },
              onDoubleTap: () {
                print('Double tap detected for reply: ${message.content}');
                HapticFeedback.lightImpact();
                _showMessageActions(message);
              },
              onLongPress: () {
                print('Long press detected for reply: ${message.content}');
                HapticFeedback.lightImpact();
                _showMessageActions(message);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(
                  left: isMe ? 32 : 0,
                  right: isMe ? 0 : 32,
                  bottom: 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Smaller padding
                decoration: BoxDecoration(
                  gradient: isMe 
                      ? LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.8),
                            AppTheme.primaryColor.withOpacity(0.6),
                          ],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE8EAED), Color(0xFFF1F3F4)],
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe 
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply indicator
                    Container(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 12,
                            color: isMe 
                                ? Colors.white.withOpacity(0.8)
                                : AppTheme.primaryColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: isMe 
                                  ? Colors.white.withOpacity(0.8)
                                  : AppTheme.primaryColor.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reply content
                    Text(
                      message.isDeleted ? message.content : message.content,
                      style: TextStyle(
                        color: message.isDeleted
                            ? (isMe ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryColor)
                            : (isMe ? Colors.white : AppTheme.textPrimaryColor),
                        fontSize: 14,
                        height: 1.3,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isMe 
                                ? Colors.white.withOpacity(0.7)
                                : AppTheme.textSecondaryColor,
                            fontSize: 10,
                          ),
                        ),
                        if (isMe && !message.isDeleted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all,
                            size: 12,
                            color: message.isRead 
                                ? Colors.blue[300]
                                : Colors.white.withOpacity(0.7),
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
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool showAvatar) {
    final otherUserName = widget.conversation.getOtherUserName(widget.currentUserId);
    final otherUserProfileImage = widget.conversation.getOtherUserProfileImage(widget.currentUserId);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Other user avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 8),
              child: showAvatar
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: otherUserProfileImage != null
                          ? NetworkImage(otherUserProfileImage)
                          : null,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.7),
                      child: otherUserProfileImage == null
                          ? Text(
                              otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    )
                  : null,
            ),
          ],
          
          // Message bubble
          Flexible(
            child: GestureDetector(
              onTap: () {
                print('Tap detected for message: ${message.content}');
              },
              onDoubleTap: () {
                print('Double tap detected for message: ${message.content}');
                HapticFeedback.lightImpact();
                _showMessageActions(message);
              },
              onLongPress: () {
                print('Long press detected for message: ${message.content}');
                HapticFeedback.lightImpact(); // Add haptic feedback
                _showMessageActions(message);
              },
              behavior: HitTestBehavior.opaque, // Ensure the entire area is tappable
              child: Container(
                margin: EdgeInsets.only(
                  left: isMe ? 32 : 0,
                  right: isMe ? 0 : 32,
                  bottom: 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isMe 
                      ? AppTheme.primaryGradient
                      : const LinearGradient(
                          colors: [Color(0xFFF1F3F4), Color(0xFFE8EAED)],
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe 
                          ? AppTheme.primaryColor.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message content
                    Text(
                      message.isDeleted ? message.content : message.content,
                      style: TextStyle(
                        color: message.isDeleted
                            ? (isMe ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryColor)
                            : (isMe ? Colors.white : AppTheme.textPrimaryColor),
                        fontSize: 15,
                        height: 1.4,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isMe 
                                ? Colors.white.withOpacity(0.8)
                                : AppTheme.textSecondaryColor,
                            fontSize: 11,
                          ),
                        ),
                        if (isMe && !message.isDeleted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all,
                            size: 14,
                            color: message.isRead 
                                ? Colors.blue[300]
                                : Colors.white.withOpacity(0.8),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.scale(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Reply preview
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyToMessage!.senderName}',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyToMessage!.content,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    onPressed: _clearReply,
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: AppTheme.textSecondaryColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedBuilder(
                    animation: _sendButtonAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.8 + (_sendButtonAnimation.value * 0.2),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      // Today - show time
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else {
      // Other days - show date
      return '${time.day}/${time.month}';
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement clear chat functionality
            },
            child: const Text('Clear', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text('Are you sure you want to block this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement block user functionality
            },
            child: const Text('Block', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

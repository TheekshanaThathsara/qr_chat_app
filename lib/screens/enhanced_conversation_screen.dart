import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../providers/conversation_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

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

    // Send the message
    await conversationProvider.sendMessage(
      widget.conversation.id,
      currentUser.id,
      currentUser.username,
      text,
    );

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
                child: Row(
                  children: [
                    Container(
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
                            'Online',
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
            
            return _buildMessageBubble(message, isMe, showAvatar);
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
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 15,
                      height: 1.4,
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
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ],
                  ),
                ],
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
      padding: const EdgeInsets.all(16),
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
            const SizedBox(width: 8),
            ScaleTransition(
              scale: _sendButtonAnimation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
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

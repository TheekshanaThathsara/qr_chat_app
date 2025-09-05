import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/providers/conversation_provider.dart';
import 'package:instant_chat_app/providers/chat_provider.dart';
import 'package:instant_chat_app/screens/qr_scanner_screen.dart';
import 'package:instant_chat_app/screens/conversation_screen.dart';
import 'package:instant_chat_app/screens/profile_screen.dart';
import 'package:instant_chat_app/screens/settings_screen.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/models/conversation.dart';
import 'package:instant_chat_app/services/firebase_service.dart';
import 'package:instant_chat_app/widgets/enhanced_conversation_tile.dart';
import 'package:instant_chat_app/screens/login_screen.dart';
import 'package:instant_chat_app/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DirectMessageHomeScreen extends StatefulWidget {
  const DirectMessageHomeScreen({super.key});

  @override
  State<DirectMessageHomeScreen> createState() => _DirectMessageHomeScreenState();
}

class _DirectMessageHomeScreenState extends State<DirectMessageHomeScreen> with WidgetsBindingObserver {
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversations();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    // Stop real-time listeners when leaving the screen
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    conversationProvider.stopConversationsListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        if (userProvider.currentUser != null) {
          // userProvider.setUserOnlineStatus(true);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background or closed
        if (userProvider.currentUser != null) {
          // userProvider.setUserOnlineStatus(false);
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeConversations() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      await conversationProvider.loadConversations(userProvider.currentUser!.id);
      // Also initialize chat provider to set up real-time profile listeners
      await chatProvider.initializeChat(userProvider.currentUser!);
    }
  }

  void _showMyQRCode() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'My QR Code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this QR code with friends to start chatting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: user.id,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (result != null && mounted) {
      await _handleQrResult(result);
    }
  }

  Future<void> _handleQrResult(String scannedUserId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      _showError('Please login first');
      return;
    }

    if (scannedUserId == currentUser.id) {
      _showError('You cannot start a conversation with yourself');
      return;
    }

    try {
      print('🔍 Attempting to start conversation with user: $scannedUserId');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Fetch the other user's details
      User? otherUser = await _firebaseService.fetchUserById(scannedUserId);
      
      if (otherUser == null) {
        Navigator.of(context).pop(); // Dismiss loading
        _showError('User not found. Please make sure the QR code is valid.');
        return;
      }

      print('✅ Found user: ${otherUser.username}');

      // Start or get existing conversation
      Conversation? conversation = await conversationProvider.startConversation(currentUser, otherUser);
      
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      if (conversation != null) {
        print('💬 Conversation started: ${conversation.id}');
        
        // Refresh conversations to ensure both users see the new conversation
        await conversationProvider.refreshConversations(currentUser.id);
        
        // Small delay to ensure UI updates are processed
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate to conversation screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationScreen(
                conversation: conversation,
                currentUserId: currentUser.id,
              ),
            ),
          );
        }
      } else {
        _showError('Failed to start conversation');
      }
      
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('❌ Error handling QR result: $e');
      _showError('Failed to start conversation: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                style: TextStyle(color: Colors.white),
                autofocus: true,
                onChanged: (value) {
                  // TODO: Implement search functionality
                },
              )
            : Text(
                'Messages',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        elevation: 0,
        actions: [
          if (_showSearchBar)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _showSearchBar = false;
                  _searchController.clear();
                });
              },
            )
          else ...[
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearchBar = true;
                });
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'my_qr':
                    _showMyQRCode();
                    break;
                  case 'scan_qr':
                    _scanQRCode();
                    break;
                  case 'profile':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                    break;
                  case 'settings':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'my_qr',
                  child: Text('My QR Code', style: TextStyle(color: Colors.black)),
                ),
                PopupMenuItem(
                  value: 'scan_qr',
                  child: Text('Scan QR Code', style: TextStyle(color: Colors.black)),
                ),
                PopupMenuDivider(color: Colors.white, height: 1),
                PopupMenuItem(
                  value: 'profile',
                  child: Text('Profile', style: TextStyle(color: Colors.black)),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings', style: TextStyle(color: Colors.black)),
                ),
                PopupMenuDivider(color: Colors.white, height: 1),
                PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout', style: TextStyle(color: Colors.black)),
                ),
              ],
              color: Colors.white,
            ),
          ],
        ],
      ),
      body: Consumer2<UserProvider, ConversationProvider>(
        builder: (context, userProvider, conversationProvider, child) {
          if (userProvider.currentUser == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Please login to continue'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _logout,
                    child: Text('Go to Login'),
                  ),
                ],
              ),
            );
          }

          if (conversationProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading conversations...',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            );
          }

          final conversations = conversationProvider.conversations;
          final currentUserId = userProvider.currentUser!.id;

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF9800), // Bright orange
                          Color(0xFFD84315), // Dark orange
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scan someone\'s QR code to start your first conversation!',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _scanQRCode,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Scan QR Code'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return EnhancedConversationTile(
                conversation: conversation,
                currentUserId: currentUserId,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConversationScreen(
                        conversation: conversation,
                        currentUserId: currentUserId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.white, size: 28),
              onPressed: _showMyQRCode,
              tooltip: 'Show My QR Code',
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _scanQRCode,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.logout();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError('Failed to logout: $e');
    }
  }
}

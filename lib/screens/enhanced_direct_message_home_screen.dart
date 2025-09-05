import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/providers/conversation_provider.dart';
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

class EnhancedDirectMessageHomeScreen extends StatefulWidget {
  const EnhancedDirectMessageHomeScreen({super.key});

  @override
  State<EnhancedDirectMessageHomeScreen> createState() => _EnhancedDirectMessageHomeScreenState();
}

class _EnhancedDirectMessageHomeScreenState extends State<EnhancedDirectMessageHomeScreen> 
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversations();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _animationController.dispose();
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
        if (userProvider.currentUser != null) {
          // userProvider.setUserOnlineStatus(true);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
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

    if (userProvider.currentUser != null) {
      await conversationProvider.loadConversations(userProvider.currentUser!.id);
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
              const SizedBox(height: 24),
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
      
      // Show modern loading dialog
      _showLoadingDialog();
      
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

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Starting conversation...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
      ),
      title: _showSearchBar
          ? _buildSearchField()
          : const Text(
              'Messages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
      actions: _buildAppBarActions(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search conversations...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      style: const TextStyle(color: Colors.white),
      autofocus: true,
      onChanged: (value) {
        // TODO: Implement search functionality
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_showSearchBar) {
      return [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _showSearchBar = false;
              _searchController.clear();
            });
          },
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: () {
          setState(() {
            _showSearchBar = true;
          });
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
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
          const PopupMenuItem(value: 'my_qr', child: Text('My QR Code')),
          const PopupMenuItem(value: 'scan_qr', child: Text('Scan QR Code')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'profile', child: Text('Profile')),
          const PopupMenuItem(value: 'settings', child: Text('Settings')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'logout', child: Text('Logout')),
        ],
      ),
    ];
  }

  Widget _buildBody() {
    return Consumer2<UserProvider, ConversationProvider>(
      builder: (context, userProvider, conversationProvider, child) {
        if (userProvider.currentUser == null) {
          return _buildLoginPrompt();
        }

        if (conversationProvider.isLoading) {
          return _buildLoadingState();
        }

        final conversations = conversationProvider.conversations;
        final currentUserId = userProvider.currentUser!.id;

        if (conversations.isEmpty) {
          return _buildEmptyState();
        }

        return _buildConversationsList(conversations, currentUserId);
      },
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Please login to continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access your conversations and connect with friends',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _logout,
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading conversations...',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.scale(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan someone\'s QR code to start your first conversation!',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _scanQRCode,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList(List<Conversation> conversations, String currentUserId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Recent Chats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
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
          ),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
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
    );
  }

  void _logout() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.logout();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError('Failed to logout: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/providers/chat_provider.dart';
import 'package:instant_chat_app/screens/qr_scanner_screen.dart';
import 'package:instant_chat_app/screens/chat_screen.dart';
import 'package:instant_chat_app/screens/profile_screen.dart';
import 'package:instant_chat_app/services/database_service.dart';
import 'package:instant_chat_app/services/firebase_service.dart';
import 'package:instant_chat_app/models/user.dart';
import 'package:instant_chat_app/models/contact.dart';
import 'package:uuid/uuid.dart';
import 'package:instant_chat_app/screens/settings_screen.dart';
import 'package:instant_chat_app/screens/camera_view_screen.dart';
import 'package:instant_chat_app/widgets/chat_room_tile.dart';
import 'package:instant_chat_app/widgets/quick_actions_modal.dart';
import 'package:instant_chat_app/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Use post frame callback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        userProvider.updateOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        userProvider.updateOnlineStatus(false);
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeChat() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      await chatProvider.initializeChat(userProvider.currentUser!);
    }
  }

  void _showQuickActionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const QuickActionsModal(),
    );
  }

  void _showScannerScreen() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      _handleQrResult(result);
    }
  }

  Future<void> _handleQrResult(String qrData) async {
    if (qrData.startsWith('room:')) {
      final roomId = qrData.substring(5);

      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);

        if (userProvider.currentUser != null) {
          // Try to join the room
          await chatProvider.joinChatRoom(roomId, userProvider.currentUser!);

          // Find the joined room and navigate to it
          final joinedRoom = chatProvider.chatRooms.firstWhere(
            (room) => room.id == roomId,
            orElse: () => throw Exception('Room not found'),
          );

          if (mounted) {
            _openChatRoom(joinedRoom);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Joined room: ${joinedRoom.name}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
        }
      }
    } else if (qrData.startsWith('user:')) {
      final parts = qrData.split(':');
      if (parts.length >= 2) {
        final userId = parts[1];
        final username = parts.length >= 3 ? parts[2] : '';

        final firebaseService = FirebaseService();
        final databaseService = DatabaseService();

        try {
          // Try to fetch remote user
          User? remoteUser;
          try {
            remoteUser = await firebaseService.fetchUserById(userId);
          } catch (e) {
            debugPrint('Error fetching user by id: $e');
          }

          final effectiveUser =
              remoteUser ??
              User(
                id: userId,
                username: username,
                email: '',
                lastSeen: DateTime.now(),
                isOnline: false,
              );

          if (remoteUser == null) {
            try {
              final toSave = effectiveUser.copyWith(
                username: effectiveUser.username.isNotEmpty
                    ? effectiveUser.username
                    : 'Unknown',
              );
              await firebaseService.saveUserToFirebase(toSave);
            } catch (e) {
              debugPrint('Failed to create minimal Firestore user: $e');
            }
          }

          // Check contact exists
          final isContact = await databaseService.isContactExists(
            effectiveUser.id,
          );
          if (isContact) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${effectiveUser.username} is already in your contacts',
                  ),
                ),
              );
            }
            return;
          }

          // Add contact and start chat
          final contact = Contact(
            id: const Uuid().v4(),
            userId: effectiveUser.id,
            username: effectiveUser.username,
            profileImage: effectiveUser.profileImage,
            addedAt: DateTime.now(),
          );

          await databaseService.addContact(contact);

          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );

          if (userProvider.currentUser == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in to start a chat')),
              );
            }
            return;
          }

          // Try to reuse existing private room
          final existing = await databaseService.getPrivateRoomBetweenUsers(
            userProvider.currentUser!.id,
            effectiveUser.id,
          );

          if (existing != null) {
            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(chatRoom: existing),
              ),
            );
            return;
          }

          final roomName = effectiveUser.username.isNotEmpty
              ? effectiveUser.username
              : 'Private Chat';
          final chatRoom = await chatProvider.createChatRoom(
            name: roomName,
            creator: userProvider.currentUser!,
            isPrivate: true,
          );

          await chatProvider.joinChatRoom(chatRoom.id, effectiveUser);

          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatRoom: chatRoom),
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to process user QR: $e')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
        }
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
    }
  }

  void _openChatRoom(chatRoom) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => ChatScreen(chatRoom: chatRoom)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _showSearchBar
            ? SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _showSearchBar = false;
                          _searchController.clear();
                        });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search chat rooms...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        cursorColor: Colors.white,
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              )
            : const Text('Instant Chat'),
        actions: !_showSearchBar
            ? [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CameraViewScreen(),
                      ),
                    );
                  },
                  tooltip: 'Camera',
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _showSearchBar = true;
                    });
                  },
                  tooltip: 'Search',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                        break;
                      case 'settings':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        break;
                      case 'logout':
                        _showLogoutDialog();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Profile'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Logout'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ]
            : [],
      ),
      body: Consumer2<UserProvider, ChatProvider>(
        builder: (context, userProvider, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chatProvider.chatRooms.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.loadChatRooms(),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: chatProvider.chatRooms.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 72, // Align with content after avatar
                endIndent: 16,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final chatRoom = chatProvider.chatRooms[index];
                return ChatRoomTile(
                  chatRoom: chatRoom,
                  onTap: () => _openChatRoom(chatRoom),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Chat Room'),
                        content: const Text(
                          'Are you sure you want to delete this chat room?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await Provider.of<ChatProvider>(
                        context,
                        listen: false,
                      ).deleteChatRoom(chatRoom.id);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActionsModal,
        tooltip: 'Quick Actions',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat, size: 32),
                  onPressed: () {
                    // Go to chat list or main chat screen
                    // You can customize navigation here
                  },
                  tooltip: 'Chat',
                ),
                const Text('Chat'),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, size: 32),
                  onPressed: _showScannerScreen,
                  tooltip: 'Scan QR',
                ),
                const Text('Scan QR'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Chat Rooms Yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a new chat room or scan a QR code to join an existing one',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _showQuickActionsModal,
                  icon: const Icon(Icons.add),
                  label: const Text('Quick Actions'),
                ),
                OutlinedButton.icon(
                  onPressed: _showScannerScreen,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.disconnect();
      await userProvider.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

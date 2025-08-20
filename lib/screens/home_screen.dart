import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/providers/chat_provider.dart';
import 'package:instant_chat_app/screens/qr_scanner_screen.dart';
import 'package:instant_chat_app/screens/create_room_screen.dart';
import 'package:instant_chat_app/screens/chat_screen.dart';
import 'package:instant_chat_app/screens/profile_screen.dart';
import 'package:instant_chat_app/screens/settings_screen.dart';
import 'package:instant_chat_app/widgets/chat_room_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
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

  void _showCreateRoomModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CreateRoomScreen(),
    );
  }

  void _showScannerScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const QrScannerScreen()));
  }

  void _openChatRoom(chatRoom) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ChatScreen(chatRoom: chatRoom)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instant Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showScannerScreen,
            tooltip: 'Scan QR Code',
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
        ],
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.chatRooms.length,
              itemBuilder: (context, index) {
                final chatRoom = chatProvider.chatRooms[index];
                return ChatRoomTile(
                  chatRoom: chatRoom,
                  onTap: () => _openChatRoom(chatRoom),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRoomModal,
        tooltip: 'Create New Chat Room',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  chatProvider.isConnected
                      ? Icons.circle
                      : Icons.circle_outlined,
                  color: chatProvider.isConnected ? Colors.green : Colors.red,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  chatProvider.isConnected ? 'Connected' : 'Disconnected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chatProvider.isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          );
        },
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
                  onPressed: _showCreateRoomModal,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Room'),
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
        Navigator.of(context).pushReplacementNamed('/welcome');
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

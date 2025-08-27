import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/user.dart';
import '../models/chat_room.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../screens/create_room_screen.dart';
import '../screens/chat_screen.dart';

class QuickActionsModal extends StatefulWidget {
  const QuickActionsModal({super.key});

  @override
  State<QuickActionsModal> createState() => _QuickActionsModalState();
}

class _QuickActionsModalState extends State<QuickActionsModal> {
  final DatabaseService _databaseService = DatabaseService();
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _safeMaybePop([dynamic result]) async {
    try {
      if (Navigator.canPop(context)) {
        await Navigator.of(context).maybePop(result);
        return;
      }
    } catch (e) {
      // ignore
    }

    try {
      await Navigator.of(context, rootNavigator: true).maybePop(result);
    } catch (e) {
      debugPrint('safeMaybePop failed: $e');
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _databaseService.getContacts();
      setState(() {
        _contacts = contacts;
      });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flash_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Choose an action below',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan QR Code',
                  subtitle: 'Scan to join rooms or add contacts',
                  color: Colors.blue,
                  onTap: () => _navigateToScanner(),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.qr_code,
                  title: 'My QR Code',
                  subtitle: 'Share your QR code with others',
                  color: Colors.green,
                  onTap: () => _showMyQRCode(),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.contacts,
                  title: 'My Contacts',
                  subtitle: '${_contacts.length} contacts saved',
                  color: Colors.orange,
                  onTap: () => _showContacts(),
                  trailing: _contacts.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_contacts.length}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.add_circle,
                  title: 'Create Chat Room',
                  subtitle: 'Start a new group conversation',
                  color: Colors.purple,
                  onTap: () => _createChatRoom(),
                ),
                const SizedBox(height: 24),

                // Recent Activity Section (if contacts exist)
                if (_contacts.isNotEmpty) ...[
                  _buildSectionHeader('Recent Contacts'),
                  const SizedBox(height: 12),
                  ..._buildRecentContacts(),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  List<Widget> _buildRecentContacts() {
    final recentContacts = _contacts.take(3).toList();
    return recentContacts.map((contact) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 20,
              child: Text(
                contact.username.isNotEmpty
                    ? contact.username[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              contact.username,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Added ${_formatDate(contact.addedAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.chat, size: 20),
              onPressed: () => _startChatWithContact(contact),
              tooltip: 'Start Chat',
            ),
          ),
        ),
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToScanner() {
    _safeMaybePop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const QRScannerModal(),
    );
  }

  void _showMyQRCode() {
    _safeMaybePop();
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'My QR Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Share this QR code with others to add you as a contact',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'user:${user.id}:${user.username}',
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'ID: ${user.id}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContacts() {
    _safeMaybePop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          ContactsModal(contacts: _contacts, onContactsChanged: _loadContacts),
    );
  }

  void _createChatRoom() {
    _safeMaybePop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CreateRoomScreen(),
    );
  }

  Future<void> _startChatWithContact(Contact contact) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting chat with ${contact.username}...')),
      );
    }
  }
}

// Separate QR Scanner Modal
class QRScannerModal extends StatefulWidget {
  const QRScannerModal({super.key});

  @override
  State<QRScannerModal> createState() => _QRScannerModalState();
}

class _QRScannerModalState extends State<QRScannerModal> {
  final DatabaseService _databaseService = DatabaseService();

  Future<void> _safeMaybePop([dynamic result]) async {
    try {
      if (Navigator.canPop(context)) {
        await Navigator.of(context).maybePop(result);
        return;
      }
    } catch (e) {
      // ignore
    }

    try {
      await Navigator.of(context, rootNavigator: true).maybePop(result);
    } catch (e) {
      debugPrint('safeMaybePop failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Point your camera at a QR code',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _handleQRResult(barcode.rawValue!);
                          return;
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ),

          // Instructions
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scan user QR codes to add contacts or room QR codes to join conversations',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQRResult(String qrData) async {
    // Do not pop immediately - keep this widget's context mounted while
    // we perform async work. We'll close the scanner only when needed and
    // push using the root navigator to avoid using a disposed context.

    if (qrData.startsWith('user:')) {
      try {
        final parts = qrData.split(':');
        // Accept both formats: 'user:{id}' and 'user:{id}:{username}'
        if (parts.length >= 2) {
          final userId = parts[1];
          final username = parts.length >= 3 ? parts[2] : '';

          // Try to fetch authoritative user record from Firebase
          final firebaseService = FirebaseService();
          User? remoteUser;
          try {
            remoteUser = await firebaseService.fetchUserById(userId);
          } catch (e) {
            debugPrint('Error fetching user by id: $e');
          }

          // If remote user exists, use it; otherwise fall back to scanned data
          final effectiveUser =
              remoteUser ??
              User(
                id: userId,
                username: username.isNotEmpty
                    ? username
                    : (remoteUser?.username ?? ''),
                email: '',
                lastSeen: DateTime.now(),
                isOnline: false,
              );

          // If the user didn't have a Firestore doc, try to create a minimal one
          if (remoteUser == null) {
            try {
              // Ensure we have at least a sensible username to store
              final toSave = effectiveUser.copyWith(
                username: effectiveUser.username.isNotEmpty
                    ? effectiveUser.username
                    : 'Unknown',
              );
              await FirebaseService().saveUserToFirebase(toSave);
              debugPrint(
                'Created minimal Firestore user for scanned id=${toSave.id}',
              );
            } catch (e) {
              debugPrint('Failed to create minimal Firestore user: $e');
            }
          }

          // Check if already a contact
          final isContact = await _databaseService.isContactExists(
            effectiveUser.id,
          );

          if (!mounted) return;
          if (isContact) {
            // Notify user and then close scanner and navigate to existing chat
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${effectiveUser.username} is already in your contacts — opening chat...',
                ),
              ),
            );
            // Close scanner if open and navigate to existing chat (reuse room if present)
            await _safeMaybePop();
            // Try to reuse existing private room and open chat
            await _createPrivateChatWithUser(effectiveUser);
            return;
          }

          // Not a contact: close scanner, add contact and immediately open chat
          await _safeMaybePop();
          await _addContact(effectiveUser);
        }
      } catch (e, st) {
        debugPrint('Error processing user QR: $e\n$st');
        if (!mounted) return;
        // Show a clear popup so the user sees the exact error
        try {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Failed to process user QR'),
              content: Text('Failed to process user QR: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } catch (dialogError) {
          // Fallback to snackbar if dialog fails
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process user QR: $e')),
          );
        }
      }
    } else if (qrData.startsWith('room:')) {
      final roomId = qrData.substring(5);
      // Close scanner before joining room
      await _safeMaybePop();
      await _handleRoomQR(roomId);
    } else {
      await _safeMaybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid QR code')));
    }
  }

  // ...existing code...

  Future<void> _addContact(User user) async {
    try {
      final contact = Contact(
        id: const Uuid().v4(),
        userId: user.id,
        username: user.username,
        profileImage: user.profileImage,
        addedAt: DateTime.now(),
      );

      await _databaseService.addContact(contact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.username} added to contacts')),
        );
        // After adding contact, start a private chat with them
        await _createPrivateChatWithUser(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add contact')));
      }
    }
  }

  Future<void> _createPrivateChatWithUser(User otherUser) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final currentUser = userProvider.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to start a chat')),
          );
        }
        return;
      }

      // Try to find an existing private room between currentUser and otherUser
      final existing = await _databaseService.getPrivateRoomBetweenUsers(
        currentUser.id,
        otherUser.id,
      );

      if (existing != null) {
        // Ensure chat provider has the room loaded
        await chatProvider.loadChatRooms();
        if (!mounted) return;
        // If this is a private room between two users, persist a friend-friendly name
        ChatRoom displayRoom = existing;
        try {
          if (existing.isPrivate && existing.participants.length == 2) {
            final other = existing.participants.firstWhere(
              (p) => p.id != currentUser.id,
              orElse: () => existing.participants.first,
            );
            final desiredName = other.username.isNotEmpty
                ? 'Chat with ${other.username}'
                : existing.name;
            if (existing.name != desiredName) {
              // Persist updated name and reload chat rooms so UI reflects it
              displayRoom = existing.copyWith(name: desiredName);
              try {
                await _databaseService.saveChatRoom(displayRoom);
                await chatProvider.loadChatRooms();
              } catch (e) {
                debugPrint('Failed to persist chat room name: $e');
              }
              try {
                await FirebaseService().saveChatRoomToFirebase(displayRoom);
              } catch (e) {
                debugPrint('Failed to save chat room to Firebase: $e');
              }
            } else {
              displayRoom = existing;
            }
          }
        } catch (_) {}

        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatRoom: displayRoom),
          ),
        );
        return;
      }

      // Create a private chat room locally
      final roomName = otherUser.username.isNotEmpty
          ? 'Chat with ${otherUser.username}'
          : 'Private Chat';
      final chatRoom = await chatProvider.createChatRoom(
        name: roomName,
        creator: currentUser,
        isPrivate: true,
      );

      // Add the other user as a participant
      await chatProvider.joinChatRoom(chatRoom.id, otherUser);

      // Re-fetch the saved room (so participants are up-to-date) and navigate
      final updatedRoom = await _databaseService.getChatRoom(chatRoom.id);
      final toOpen = updatedRoom ?? chatRoom;

      try {
        await FirebaseService().saveChatRoomToFirebase(toOpen);
      } catch (e) {
        debugPrint('Failed to save new chat room to Firebase: $e');
      }
      // Navigate to the chat screen
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (context) => ChatScreen(chatRoom: toOpen)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create chat: $e')));
    }
  }

  Future<void> _handleRoomQR(String roomId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      if (userProvider.currentUser != null) {
        await chatProvider.joinChatRoom(roomId, userProvider.currentUser!);

        if (!mounted) return;
        // Fetch the chat room and navigate to ChatScreen
        final joinedRoom = await _databaseService.getChatRoom(roomId);
        if (joinedRoom != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined chat room successfully')),
          );
          try {
            await FirebaseService().saveChatRoomToFirebase(joinedRoom);
          } catch (e) {
            debugPrint('Failed to save joined room to Firebase: $e');
          }
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatRoom: joinedRoom),
            ),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
    }
  }
}

// Contacts Modal
class ContactsModal extends StatefulWidget {
  final List<Contact> contacts;
  final VoidCallback onContactsChanged;

  const ContactsModal({
    super.key,
    required this.contacts,
    required this.onContactsChanged,
  });

  @override
  State<ContactsModal> createState() => _ContactsModalState();
}

class _ContactsModalState extends State<ContactsModal> {
  final DatabaseService _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.contacts,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Contacts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.contacts.length} contacts',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Contacts List
          Expanded(
            child: widget.contacts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.contacts.length,
                    itemBuilder: (context, index) {
                      final contact = widget.contacts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: Text(
                                contact.username.isNotEmpty
                                    ? contact.username[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              contact.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Added ${_formatDate(contact.addedAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                switch (value) {
                                  case 'chat':
                                    await _startChat(contact);
                                    break;
                                  case 'delete':
                                    await _deleteContact(contact);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'chat',
                                  child: ListTile(
                                    leading: Icon(Icons.chat),
                                    title: Text('Start Chat'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    title: Text('Delete'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
          Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Contacts Yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan QR codes to add contacts',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _startChat(Contact contact) async {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting chat with ${contact.username}...')),
    );
  }

  Future<void> _deleteContact(Contact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact'),
        content: Text('Remove ${contact.username} from your contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _databaseService.deleteContact(contact.id);
        widget.onContactsChanged();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${contact.username} removed from contacts')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete contact')),
        );
      }
    }
  }
}

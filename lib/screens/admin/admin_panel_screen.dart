import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/models/user_model.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/email_service.dart';
import 'package:provider/provider.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/screens/admin/upload_draw_screen.dart';
import 'package:app/screens/admin/admin_draws_list_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserModel> _pendingUsers = [];
  List<UserModel> _approvedUsers = [];
  List<UserModel> _rejectedUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending'; // 'pending', 'approved', 'rejected', 'all'

  @override
  void initState() {
    super.initState();
    // screen load hote hi users fetch kar rahe hain
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true); // loader show karna hai jab tak data aa raha hai

    try {
      // firestore se sare users la rahe hain (latest pehle)
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
      // sirf normal users chahiye (admin nahi)
      final allUsers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
          .where((user) => user.userType == 'normal') // Only normal users
          .toList();

      setState(() {
        // status ke hisaab se users alag alag list me daal   rahe hain
        _pendingUsers = allUsers.where((user) => user.status == 'pending').toList();
        _approvedUsers = allUsers.where((user) => user.status == 'approved').toList();
        _rejectedUsers = allUsers.where((user) => user.status == 'rejected').toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e'); // agar koi issue aye to terminal me  show hoga
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserStatus(String userId, String status) async {
    try {
      // pehle user ka data nikle ga  taa k email bhej saken
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'];
      final userName = '${userData['firstName']} ${userData['lastName']}';

      print('Sending email to: $userEmail');
      print('User name: $userName');
      print('Status: $status');

      // firestore DB  me status update kar rahe hain
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'isApproved': status == 'approved',
        'isActive': status == 'approved',
      });

      print('User status updated in Firebase');

      bool emailSent = false;
      // status k hisaab se email bhejna
      if (status == 'approved') {
        emailSent = await EmailService.sendApprovalEmail(
          toEmail: userEmail,
          userName: userName,
        );
        print('Approval email sent: $emailSent');
      } else if (status == 'rejected') {
        emailSent = await EmailService.sendRejectionEmail(
          toEmail: userEmail,
          userName: userName,
        );
        print('Rejection email sent: $emailSent');
      }

      // list dobara refresh kar rahe hain
      await _loadUsers();


      if (emailSent) {
        // user ko result show karna
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $status successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $status  failed to send'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      //error handling k leye
      print('Error in _updateUserStatus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// yeh function approved user ka pin reset karega
  Future<void> _resetUserPin(String userId) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset PIN'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will reset the user PIN to:'),
            SizedBox(height: 10),
            Text('0000', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
            SizedBox(height: 10),
            Text('An email notification will be sent to the user.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset PIN', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found'), backgroundColor: Colors.red),
          );
          return;
        }
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final userEmail = userData['email']?.toString();
        final userName = userData['firstName'] != null || userData['lastName'] != null
            ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim()
            : (userData['name']?.toString() ?? 'User');
        final defaultPinHash = AuthService.getDefaultPinHash();
        await _firestore.collection('users').doc(userId).update({
          'pin': defaultPinHash,
        });

        bool emailSent = false;
        if (userEmail != null && userEmail.isNotEmpty) {
          emailSent = await EmailService.sendPinResetEmail(
            toEmail: userEmail,
            userName: userName,
          );
        }

        if (emailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN reset to 0000 & email sent!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (userEmail != null && userEmail.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN reset to 0000 but email failed'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN reset to 0000'),
              backgroundColor: Colors.green,
            ),
          );
        }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user.firstName} ${user.lastName}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(user.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.mobileNo,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_city, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.city,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.home, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user.address,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Registered: ${_formatDate(user.createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (user.status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateUserStatus(user.uid, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateUserStatus(user.uid, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ] else if (user.status == 'approved') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _resetUserPin(user.uid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.lock_reset, size: 18),
                      label: const Text('Reset PIN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateUserStatus(user.uid, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Deactivate'),
                    ),
                  ),
                ],
              ),
            ] else if (user.status == 'rejected') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateUserStatus(user.uid, 'approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
// jo tab select hai os k  hisaab se list return karega
  List<UserModel> _getFilteredUsers() {
    switch (_selectedFilter) {
      case 'pending':
        return _pendingUsers;
      case 'approved':
        return _approvedUsers;
      case 'rejected':
        return _rejectedUsers;
      case 'all':
        return [..._pendingUsers, ..._approvedUsers, ..._rejectedUsers];
      default:
        return _pendingUsers;
    }
  }
// admin logout function
  Future<void> _logout() async {
    try {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (shouldLogout != true) return;

      setState(() {
        _isLoading = true;
      });

      final authService = Provider.of<AuthService>(context, listen: false);

      // auth service file me funtion add ha whan  se sign out kar rahe hain
      await authService.signOut();
      // AuthWrapper rebuilds to LoginScreen.
    } catch (e) {
      print('Logout error: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : AppColors.primaryColor,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.onSurface
            : Colors.white,
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminDrawsListScreen()),
              );
            },
            tooltip: 'Uploaded Draws',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UploadDrawScreen()),
              );
            },
            tooltip: 'Add Draw (Upload TXT)',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                _buildFilterTab('pending', 'Pending (${_pendingUsers.length})'),
                _buildFilterTab('approved', 'Approved (${_approvedUsers.length})'),
                _buildFilterTab('rejected', 'Rejected (${_rejectedUsers.length})'),
                _buildFilterTab('all', 'All Users'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                ? Center(
              child: Text(
                'No users found',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  return _buildUserCard(filteredUsers[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final unselected = theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedFilter == value ? primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _selectedFilter == value ? primary : unselected,
              fontWeight: _selectedFilter == value
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

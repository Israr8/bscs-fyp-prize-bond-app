import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/models/user_model.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/email_service.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import 'login_screen.dart';

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
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final allUsers = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
          .where((user) => user.userType == 'normal') // Only normal users
          .toList();

      setState(() {
        _pendingUsers = allUsers.where((user) => user.status == 'pending').toList();
        _approvedUsers = allUsers.where((user) => user.status == 'approved').toList();
        _rejectedUsers = allUsers.where((user) => user.status == 'rejected').toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserStatus(String userId, String status) async {
    try {
      // Phele user ka data fetch hoga
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'];
      final userName = '${userData['firstName']} ${userData['lastName']}';

      print('📧 Sending email to: $userEmail');
      print('👤 User name: $userName');
      print('📋 Status: $status');

      // STATUS UPDATE  FIREBASE
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'isApproved': status == 'approved',
        'isActive': status == 'approved',
      });

      print('✅ User status updated in Firebase');

      // Email sent (AUTOMATIC)
      bool emailSent = false;

      if (status == 'approved') {
        emailSent = await EmailService.sendApprovalEmail(
          toEmail: userEmail,
          userName: userName,
        );
        print('📨 Approval email sent: $emailSent');
      } else if (status == 'rejected') {
        emailSent = await EmailService.sendRejectionEmail(
          toEmail: userEmail,
          userName: userName,
        );
        print('📨 Rejection email sent: $emailSent');
      }

      //  REFRESH LIST
      await _loadUsers();

      //  SNACKBAR SHOW
      if (emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ User $status & email sent successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ User $status but email failed to send'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      print('❌ Error in _updateUserStatus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// PIN Reset function
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
        // Get user data
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() as Map<String, dynamic>;
        final userEmail = userData['email'];
        final userName = '${userData['firstName']} ${userData['lastName']}';

        // Reset PIN in Firestore
        const defaultPinHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        await _firestore.collection('users').doc(userId).update({
          'pin': defaultPinHash,
        });

        // Send PIN reset email
        final emailSent = await EmailService.sendPinResetEmail(
          toEmail: userEmail,
          userName: userName,
        );

        if (emailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PIN reset to 0000 & email sent!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ PIN reset but email failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
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
            // User Header with Status
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

            // User Details in Row
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

            // Address
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

            // Registration Date
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

            // Action Buttons based on status
            if (user.status == 'pending') ...[
              // Pending Users - Approve/Reject
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
              // Approved Users - PIN Reset
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
              // Rejected Users - Approve
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
// Logout Function
  Future<void> _logout() async {
    try {
      // Show confirmation dialog
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

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Get AuthService instance
      final authService = Provider.of<AuthService>(context, listen: false);

      // Sign out
      await authService.signOut();

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );

      print('✅ Admin logged out successfully');
    } catch (e) {
      print('❌ Logout error: $e');
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
        backgroundColor: AppColors.primaryColor,
        title: const Text('Admin Panel'),
        actions: [
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
          // Filter Tabs
          Container(
            color: Colors.white,
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

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                ? Center(
              child: Text(
                'No users found',
                style: GoogleFonts.inter(
                  color: Colors.grey,
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
                color: _selectedFilter == value
                    ? AppColors.primaryColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _selectedFilter == value
                  ? AppColors.primaryColor
                  : Colors.grey,
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
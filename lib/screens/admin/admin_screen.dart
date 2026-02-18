// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/utils/draw_data_loader.dart';
import 'package:app/utils/sample_data_loader.dart';
import 'package:app/utils/constants.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DrawDataLoader _drawLoader = DrawDataLoader();
  final SampleDataLoader _sampleLoader = SampleDataLoader();

  bool _isLoading = false;
  String _message = '';
  int _totalUsers = 0;
  int _totalBonds = 0;
  int _totalDraws = 0;
  int _totalScans = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Get users count
      final usersSnapshot = await _firestore.collection('users').get();
      _totalUsers = usersSnapshot.docs.length;

      // Get total bonds count (sum from all users)
      int totalBonds = 0;
      for (var userDoc in usersSnapshot.docs) {
        final bondsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('my_bonds')
            .get();
        totalBonds += bondsSnapshot.docs.length;
      }
      _totalBonds = totalBonds;

      // Get draws count
      final drawsSnapshot = await _firestore.collection('draws').get();
      _totalDraws = drawsSnapshot.docs.length;

      // Get scans count
      int totalScans = 0;
      for (var userDoc in usersSnapshot.docs) {
        final scansSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('scanned_bonds')
            .get();
        totalScans += scansSnapshot.docs.length;
      }
      _totalScans = totalScans;

      setState(() {});
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadSampleDraws() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await _drawLoader.load2024DrawResults();
      setState(() {
        _message = '✅ Sample draw results loaded successfully!';
      });
      await _loadStats(); // Refresh stats
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSamplePrizeBonds() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await _sampleLoader.addSamplePrizeBonds();
      setState(() {
        _message = '✅ Sample prize bonds loaded successfully!';
      });
      await _loadStats();
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear All Data'),
        content: const Text(
          'This will delete ALL data including:\n'
              '- All users\' bonds\n'
              '- All scan history\n'
              '- All draw results\n'
              '\nThis action cannot be undone!\n'
              'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _message = 'Clearing data...';
    });

    try {
      // Delete all users' bonds
      final usersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        // Delete my_bonds subcollection
        final bondsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('my_bonds')
            .get();
        for (var bondDoc in bondsSnapshot.docs) {
          await bondDoc.reference.delete();
        }

        // Delete scanned_bonds subcollection
        final scansSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('scanned_bonds')
            .get();
        for (var scanDoc in scansSnapshot.docs) {
          await scanDoc.reference.delete();
        }
      }

      // Delete all draws
      final drawsSnapshot = await _firestore.collection('draws').get();
      for (var drawDoc in drawsSnapshot.docs) {
        await drawDoc.reference.delete();
      }

      // Delete all prize bonds
      final prizeBondsSnapshot = await _firestore.collection('prize_bonds').get();
      for (var bondDoc in prizeBondsSnapshot.docs) {
        await bondDoc.reference.delete();
      }

      setState(() {
        _message = '✅ All data cleared successfully!';
      });
      await _loadStats();
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _viewAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'name': data['name'] ?? 'No Name',
          'isAdmin': data['isAdmin'] ?? false,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('All Users'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['isAdmin'] == true
                        ? Colors.blue
                        : Colors.grey,
                    child: Text(
                      user['name'].toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(user['name'].toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['email'].toString()),
                      Text(
                        DateFormat('dd MMM yyyy').format(user['createdAt'] as DateTime),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: user['isAdmin'] == true
                      ? const Chip(
                    label: Text('Admin'),
                    backgroundColor: Colors.blue,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                  )
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _message = '❌ Error loading users: $e';
      });
    }
  }

  Future<void> _promoteToAdmin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isAdmin': true,
        'role': 'admin',
        'permissions': ['view_stats'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _message = '✅ User promoted to admin!';
      });
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Admin Info Card
            Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'System Administrator',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future: _auth.currentUser?.reload(),
                      builder: (context, snapshot) {
                        final user = _auth.currentUser;
                        return Text(
                          user?.email ?? 'admin@pakbond.com',
                          style: const TextStyle(color: Colors.grey),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  title: 'Total Users',
                  value: _totalUsers.toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: 'Total Bonds',
                  value: _totalBonds.toString(),
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'Draw Results',
                  value: _totalDraws.toString(),
                  icon: Icons.list_alt,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  title: 'Total Scans',
                  value: _totalScans.toString(),
                  icon: Icons.qr_code_scanner,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Message Display
            if (_message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _message.contains('✅')
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _message.contains('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _message.contains('✅')
                          ? Icons.check_circle
                          : Icons.error,
                      color: _message.contains('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: _message.contains('✅')
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.download,
              title: 'Load Sample Draws',
              subtitle: 'Add sample draw results',
              color: Colors.blue,
              onPressed: _loadSampleDraws,
            ),

            _buildActionButton(
              icon: Icons.attach_money,
              title: 'Load Prize Bonds',
              subtitle: 'Add sample winning bonds',
              color: Colors.green,
              onPressed: _loadSamplePrizeBonds,
            ),

            _buildActionButton(
              icon: Icons.people,
              title: 'View All Users',
              subtitle: 'See registered users',
              color: Colors.orange,
              onPressed: _viewAllUsers,
            ),

            _buildActionButton(
              icon: Icons.dashboard,
              title: 'Manage Draws',
              subtitle: 'Add/edit draw results',
              color: Colors.purple,
              onPressed: () {
                Navigator.pushNamed(context, '/admin-draws');
              },
            ),

            _buildActionButton(
              icon: Icons.refresh,
              title: 'Refresh Stats',
              subtitle: 'Update statistics',
              color: Colors.teal,
              onPressed: _loadStats,
            ),

            const SizedBox(height: 20),

            // Danger Zone
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'These actions are irreversible. Use with extreme caution.',
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _clearAllData,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Clear All Data'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Footer Note
            const Text(
              'Note: This admin panel is for development and testing purposes. '
                  'In production, restrict access to authorized personnel only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onPressed,
        tileColor: Colors.white,
      ),
    );
  }
}
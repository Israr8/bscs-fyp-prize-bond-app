import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/screens/scan_screen.dart';
import 'package:app/screens/my_bonds_screen.dart';
import 'package:app/screens/marketplace_screen.dart';
import 'package:app/screens/draw_results_screen.dart';
import 'package:app/screens/profile_screen.dart';
import 'package:app/screens/notifications_screen.dart';
import 'package:app/widgets/custom_card.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/screens/draw_lists_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeDashboard(),
    const ScanScreen(),
    const MyBondsScreen(),
    const MarketplaceScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pakbond',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryColor,
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: _openNotifications,
              ),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: NotificationService.notificationsList,
                builder: (context, notifications, child) {
                  final unreadCount =
                      notifications.where((n) => n['isRead'] == false).length;

                  if (unreadCount == 0) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'My Bonds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
//  Dynamic HomeDashboard CLASS
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final User? user = _auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
          //  DYNAMIC User Info Card
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: user != null
              // Default data if user not logged in or data not available
                ? _firestore.collection('users').doc(user.uid).snapshots()
                : null,
            builder: (context, snapshot) {
              String userName = 'User';
              String userEmail = 'Not logged in';
              String package = 'FREE';
              String expiry = '∞';
                // Get data from Firebase Auth
              String space = '0/1,000';

              if (user != null) {
                userName =
                // Get data from Firestore if available
                    user.displayName ?? user.email?.split('@').first ?? 'User';
                userEmail = user.email ?? 'No email';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  if (userData != null) {
                    userName = userData['name']?.toString() ?? userName;
                    package = userData['package']?.toString() ?? package;
                    expiry = userData['expiry']?.toString() ?? expiry;
                    space = userData['space']?.toString() ?? space;
                  }
                }
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.3)),
                    // Profile Picture from Firestore or default
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryColor,
                      backgroundImage: snapshot.hasData &&
                              snapshot.data!.exists &&
                              (snapshot.data!.data() as Map<String, dynamic>?)?[
                                      'profileImage'] !=
                                  null &&
                              (snapshot.data!.data()
                                      as Map<String, dynamic>?)!['profileImage']
                                  .toString()
                                  .isNotEmpty
                          ? NetworkImage(
                              (snapshot.data!.data()
                                      as Map<String, dynamic>?)?['profileImage']
                                  as String,
                            ) as ImageProvider
                          : null,
                      child: snapshot.hasData &&
                              snapshot.data!.exists &&
                              (snapshot.data!.data() as Map<String, dynamic>?)?[
                                      'profileImage'] !=
                                  null &&
                              (snapshot.data!.data()
                                      as Map<String, dynamic>?)!['profileImage']
                                  .toString()
                                  .isNotEmpty
                          ? null
                          : const Icon(Icons.person,
                              size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                          // User Name
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          // User Email
                          ),
                          const SizedBox(height: 4),

                          Text(
                            userEmail,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          // Package Info
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildPackageInfo(
                                  'Package: $package', Icons.card_giftcard),
                              _buildPackageInfo(
                                  'Expiry: $expiry', Icons.calendar_today),
                              _buildPackageInfo('Space: $space', Icons.storage),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Features Grid (Unchanged)

          const SizedBox(height: 24),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,

            children: [
              CustomCard(
                title: 'Quick Check',
                icon: Icons.fact_check_outlined,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DrawResultsScreen(),
                  ),
                ),
              ),
              CustomCard(
                title: 'Quick Scan',
                icon: Icons.qr_code_scanner_rounded,
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScanScreen(),
                  ),
                ),
              ),
              CustomCard(
                title: 'My Bonds',
                icon: Icons.account_balance,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyBondsScreen(),
                  ),
                ),
              ),
              CustomCard(
                title: 'Lockers',
                icon: Icons.lock,
                color: Colors.purple,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lockers feature coming soon!'),
                    ),
                  );
                },
              ),
              CustomCard(
                title: 'Draw Lists',
                icon: Icons.list_alt,
                color: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DrawListsScreen(),
                    ),
                  );
                },
              ),
              CustomCard(
                title: 'Marketplace',
                icon: Icons.store,
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MarketplaceScreen(),
                  ),
                ),
              ),
              CustomCard(
                title: 'Missed Prizes',
                icon: Icons.warning_amber,
                color: Colors.amber,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for missed prizes...'),
                    ),
                  );
                },
              ),
              CustomCard(
                title: 'Results on Call',
                icon: Icons.phone,
                color: Colors.indigo,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Call service coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 45),
          const SizedBox(height: 20),
        ],
      ),
  // Package Info Widget
    );
  }

  Widget _buildPackageInfo(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

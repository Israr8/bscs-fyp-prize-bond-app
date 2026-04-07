import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/register_screen.dart';
import 'package:app/utils/constants.dart';
import 'package:app/widgets/custom_card.dart';
import 'package:app/screens/draw_results_screen.dart';
import 'package:app/screens/draw_lists_screen.dart';
import 'package:app/screens/marketplace_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _guestScreens = [
    GuestDashboardScreen(),
    const DrawResultsScreen(), // Search tab = Quick Search
    const GuestScanRegisterPrompt(),
    GuestMarketplaceScreen(),
    GuestProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              title: const Text('Pakbond - Guest Mode'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.login),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  tooltip: 'Login',
                ),
              ],
            ),
      body: _guestScreens[_currentIndex],
      // Search tab (index 1) shows DrawResultsScreen with its own AppBar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.confirmation_number_outlined),
            activeIcon: const Icon(Icons.confirmation_number),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Marketplace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ===========================
// Guest Dashboard Screen
// ===========================

class GuestDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guest Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest Mode',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        'Some features are limited. Register to unlock all features.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Check & Quick Scan (same as logged-in user)
          Text(
            'Quick Search',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
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
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Scan')),
                      body: const GuestScanRegisterPrompt(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Available Features (all tappable, same screens as logged-in)
          Text(
            'Available Features',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              CustomCard(
                title: 'Scan Bonds',
                icon: Icons.confirmation_number,
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Scan Bonds')),
                      body: const GuestScanRegisterPrompt(),
                    ),
                  ),
                ),
              ),
              CustomCard(
                title: 'Search Results',
                icon: Icons.search,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DrawResultsScreen(),
                  ),
                ),
              ),
              CustomCard(
                title: 'View Marketplace',
                icon: Icons.store,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MarketplaceScreen(),
                  ),
                ),
              ),
              CustomCard(
                title: 'Draw Lists',
                icon: Icons.list_alt,
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DrawListsScreen(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Limited Features
          Text(
            'Limited Features (Requires Registration)',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 16),

          Column(
            children: [
              _buildLimitedFeature('Save Bonds', Icons.bookmark_border),
              _buildLimitedFeature('Price Alerts', Icons.notifications_none),
              _buildLimitedFeature('Buy/Sell Bonds', Icons.shopping_cart),
              _buildLimitedFeature('Profile Management', Icons.person_outline),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Draws
          Text(
            'Recent Draw Results',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('draws')
                .orderBy('addedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Unable to load draws. Check connection.',
                      style: GoogleFonts.inter(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No draws available',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                );
              }

              final draws = snapshot.data!.docs;
              return Column(
                children: draws.map((doc) {
                  final raw = doc.data();
                  final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
                  final denom = data['denomination']?.toString() ?? '';
                  final drawNum = data['drawNumber']?.toString() ?? 'N/A';
                  final firstPrize = data['firstPrize']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.celebration_outlined, color: Colors.orange),
                      title: Text('Rs. $denom Draw #$drawNum'),
                      subtitle: Text('${data['city'] ?? ''} • ${_formatDrawDate(data['drawDate'] ?? data['addedAt'])}'),
                      trailing: firstPrize.isNotEmpty
                          ? Text(
                              '1st: $firstPrize',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLimitedFeature(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: GoogleFonts.inter(color: Colors.grey)),
      trailing: const Icon(Icons.lock_outline, size: 16),
    );
  }

  String _formatDrawDate(dynamic date) {
    try {
      if (date is Timestamp) {
        final d = date.toDate();
        return '${d.day}/${d.month}/${d.year}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}

// ===========================
// Guest Scan tab: register prompt (no bond input)
// ===========================

class GuestScanRegisterPrompt extends StatelessWidget {
  const GuestScanRegisterPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in required',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create an account to scan bonds and check results',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// (GuestScanScreen removed – guest sees only GuestScanRegisterPrompt)

// ===========================
// Guest Marketplace Screen (Updated with real listings)
// ===========================

class GuestMarketplaceScreen extends StatelessWidget {
  const GuestMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Marketplace access info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Guest users can view bonds in marketplace but cannot buy/sell. Register to participate.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Marketplace Listings
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('marketplace')
                  .where('isSold', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Unable to load marketplace. Check connection.',
                        style: GoogleFonts.inter(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_mall_directory_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bonds available for sale',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final raw = item.data();
                    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
                    return _buildMarketplaceItem(context, item.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceItem(BuildContext context, String id, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(data['denomination'] ?? ''),
                  backgroundColor: AppColors.primaryColor.withValues(alpha:0.1),
                ),
                Text(
                  'Rs. ${_formatPrice(data['askingPrice'])}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Bond #${data['bondNumber'] ?? ''}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              data['description'] ?? '',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['sellerName'] ?? 'Seller',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['location'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Seller contact is available after you register and complete a purchase',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Posted: ${_formatDate(data['postedDate'] ?? data['createdAt'])}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 16),

            // Guest mode restrictions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Register to buy this bond',
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic value) {
    if (value == null) return '0';
    if (value is num) return (value as num).toStringAsFixed(0);
    final n = double.tryParse(value.toString());
    return n != null ? n.toStringAsFixed(0) : '0';
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        final d = date.toDate();
        final now = DateTime.now();
        final difference = now.difference(d);

        if (difference.inDays == 0) return 'Today';
        if (difference.inDays == 1) return 'Yesterday';
        if (difference.inDays < 7) return '${difference.inDays} days ago';

        return '${d.day}/${d.month}/${d.year}';
      }
      if (date is String) return date;
      return '';
    } catch (e) {
      return '';
    }
  }
}

// ===========================
// Guest Profile Screen
// ===========================

class GuestProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Guest Profile Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Guest User',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Limited Access Mode',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Login to Your Account'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create New Account'),
            ),
          ),

          const SizedBox(height: 24),

          // Features Comparison
          Text(
            'Guest vs Registered User',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          DataTable(
            columns: const [
              DataColumn(label: Text('Feature')),
              DataColumn(label: Text('Guest')),
              DataColumn(label: Text('Registered')),
            ],
            rows: const [
              DataRow(cells: [
                DataCell(Text('Scan Bonds')),
                DataCell(Icon(Icons.check, color: Colors.green)),
                DataCell(Icon(Icons.check, color: Colors.green)),
              ]),
              DataRow(cells: [
                DataCell(Text('Search Results')),
                DataCell(Icon(Icons.check, color: Colors.green)),
                DataCell(Icon(Icons.check, color: Colors.green)),
              ]),
              DataRow(cells: [
                DataCell(Text('View Marketplace')),
                DataCell(Icon(Icons.check, color: Colors.green)),
                DataCell(Icon(Icons.check, color: Colors.green)),
              ]),
              DataRow(cells: [
                DataCell(Text('Save Bonds')),
                DataCell(Icon(Icons.close, color: Colors.red)),
                DataCell(Icon(Icons.check, color: Colors.green)),
              ]),
              DataRow(cells: [
                DataCell(Text('Buy/Sell Bonds')),
                DataCell(Icon(Icons.close, color: Colors.red)),
                DataCell(Icon(Icons.check, color: Colors.green)),
              ]),
              DataRow(cells: [
                DataCell(Text('Price Alerts')),
                DataCell(Icon(Icons.close, color: Colors.red)),
                DataCell(Icon(Icons.check, color: Colors.green)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}
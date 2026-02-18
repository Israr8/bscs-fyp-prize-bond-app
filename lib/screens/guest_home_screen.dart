import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/register_screen.dart';
import 'package:app/utils/constants.dart';
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
    GuestSearchScreen(),
    GuestScanScreen(),
    GuestMarketplaceScreen(),
    GuestProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: Colors.grey,
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
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
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

          // Features Grid
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
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildFeatureCard(
                icon: Icons.camera_alt,
                title: 'Scan Bonds',
                color: Colors.green,
                enabled: true,
              ),
              _buildFeatureCard(
                icon: Icons.search,
                title: 'Search Results',
                color: Colors.blue,
                enabled: true,
              ),
              _buildFeatureCard(
                icon: Icons.store,
                title: 'View Marketplace',
                color: Colors.orange,
                enabled: true,
              ),
              _buildFeatureCard(
                icon: Icons.history,
                title: 'Draw History',
                color: Colors.purple,
                enabled: true,
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
                .orderBy('drawDate', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final draws = snapshot.data!.docs;

              if (draws.isEmpty) {
                return const Center(child: Text('No draws available'));
              }

              return Column(
                children: draws.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.celebration_outlined, color: Colors.orange),
                      title: Text('Draw #${data['drawNumber'] ?? 'N/A'}'),
                      subtitle: Text('${data['city'] ?? ''} • ${_formatDrawDate(data['drawDate'])}'),
                      trailing: Text(
                        'Rs. ${data['firstPrize'] ?? '0'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required bool enabled,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (enabled)
              Chip(
                label: const Text('Available'),
                backgroundColor: Colors.green[50],
                labelStyle: const TextStyle(color: Colors.green),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
          ],
        ),
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
// Guest Search Screen (Updated with real search)
// ===========================

class GuestSearchScreen extends StatefulWidget {
  const GuestSearchScreen({super.key});

  @override
  State<GuestSearchScreen> createState() => _GuestSearchScreenState();
}

class _GuestSearchScreenState extends State<GuestSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchDrawResults() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      final query = _searchController.text.trim();

      // Search by draw number
      final drawQuery = await _firestore
          .collection('draws')
          .where('drawNumber', isEqualTo: query)
          .limit(10)
          .get();

      // Search by city
      final cityQuery = await _firestore
          .collection('draws')
          .where('city', isEqualTo: query)
          .limit(10)
          .get();

      // Combine results
      final allResults = [
        ...drawQuery.docs,
        ...cityQuery.docs,
      ];

      // Remove duplicates
      final uniqueIds = <String>{};
      final uniqueResults = <QueryDocumentSnapshot>[];

      for (final doc in allResults) {
        if (!uniqueIds.contains(doc.id)) {
          uniqueIds.add(doc.id);
          uniqueResults.add(doc);
        }
      }

      setState(() {
        _searchResults = uniqueResults
            .map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        })
            .toList();
      });
    } catch (e) {
      print('Search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by draw number or city...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _searchDrawResults(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchDrawResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Search'),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search Draw Results',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Search by:\n• Draw Number\n• City Name',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return _buildResultCard(result);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text('Draw #${result['drawNumber'] ?? ''}'),
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                ),
                Text(
                  result['city'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(result['drawDate'])}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (result['firstPrize'] != null)
              Text(
                '1st Prize: ${result['firstPrize']}',
                style: GoogleFonts.inter(color: Colors.green),
              ),
            const SizedBox(height: 8),
            if (result['denomination'] != null)
              Text(
                'Denomination: ${result['denomination']}',
                style: GoogleFonts.inter(color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return '${date.toDate().day}/${date.toDate().month}/${date.toDate().year}';
      }
      return date.toString();
    } catch (e) {
      return 'Unknown date';
    }
  }
}

// ===========================
// Guest Scan Screen (Updated with manual input)
// ===========================

class GuestScanScreen extends StatefulWidget {
  const GuestScanScreen({super.key});

  @override
  State<GuestScanScreen> createState() => _GuestScanScreenState();
}

class _GuestScanScreenState extends State<GuestScanScreen> {
  String _scannedText = '';
  bool _isScanning = false;

  // Simple manual input method for testing
  final TextEditingController _bondController = TextEditingController();

  Future<void> _scanBond() async {
    final bondNumber = _bondController.text.trim();

    if (bondNumber.isEmpty || bondNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit bond number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scannedText = 'Scanning bond: $bondNumber';
    });

    await Future.delayed(const Duration(seconds: 1));

    // Mock result
    setState(() {
      _isScanning = false;
      _scannedText = 'Scanned: $bondNumber';
    });

    _showScanResults(bondNumber);
  }

  void _showScanResults(String bondNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bond Number: $bondNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Mock draw results
            _buildDrawResult('December 2023', 'Karachi', 'Not a winner', '-'),
            const SizedBox(height: 12),
            _buildDrawResult('November 2023', 'Lahore', 'Not a winner', '-'),
            const SizedBox(height: 12),
            _buildDrawResult('October 2023', 'Islamabad', 'Winner', 'Rs. 15,000'),

            const SizedBox(height: 16),
            Text('Note: Guest users cannot save bonds. Register to save.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            child: const Text('Register to Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawResult(String draw, String city, String status, String prize) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status == 'Winner' ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status == 'Winner' ? Colors.green : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            status == 'Winner' ? Icons.celebration : Icons.info,
            color: status == 'Winner' ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$draw - $city', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Status: $status', style: TextStyle(
                  color: status == 'Winner' ? Colors.green : Colors.grey,
                )),
                if (prize != '-')
                  Text('Prize: $prize', style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'How to Scan',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Enter 10-digit bond number manually\n'
                      '2. Or use camera to scan (requires registration)\n'
                      '3. Check results instantly',
                  style: GoogleFonts.inter(color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bond Input
          Text(
            'Enter Bond Number',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bondController,
            decoration: InputDecoration(
              hintText: 'Enter 10-digit bond number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.confirmation_number),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Camera scanning requires registration'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 10,
          ),

          const SizedBox(height: 16),

          // Scan Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _scanBond,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isScanning
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search),
                  SizedBox(width: 8),
                  Text('Check Bond', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Camera Option (Requires Registration)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.camera_alt, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Camera Scanning',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Register to use camera for instant scanning',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                      ),
                    ],
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
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
          ),

          if (_scannedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _scannedText,
                      style: GoogleFonts.inter(color: Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Recent Scans (Local storage)
          Text(
            'Recent Checks',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentScans(),
        ],
      ),
    );
  }

  Widget _buildRecentScans() {
    // Mock recent scans
    final recentScans = [
      {'number': '1234567890', 'date': 'Today', 'result': 'Not a winner'},
      {'number': '0987654321', 'date': 'Yesterday', 'result': 'Not a winner'},
      {'number': '1122334455', 'date': '2 days ago', 'result': 'Winner'},
    ];

    return Column(
      children: recentScans.map((scan) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: Text('Bond #${scan['number']}'),
            subtitle: Text('${scan['date']} • ${scan['result']}'),
            trailing: scan['result'] == 'Winner'
                ? const Icon(Icons.celebration, color: Colors.green)
                : const Icon(Icons.close, color: Colors.grey),
          ),
        );
      }).toList(),
    );
  }
}

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
                    final data = item.data() as Map<String, dynamic>;
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
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                ),
                Text(
                  'Rs. ${data['askingPrice']?.toStringAsFixed(0) ?? '0'}',
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
                Text(
                  data['sellerName'] ?? 'Seller',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  data['location'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
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
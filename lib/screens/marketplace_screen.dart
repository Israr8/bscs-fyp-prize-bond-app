import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/utils/constants.dart';
import 'package:app/widgets/post_item_sheet.dart';
import 'package:app/models/market_item.dart'; // ✅ Import model

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _marketItemsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToMarketItems();
  }

  void _listenToMarketItems() {
    try {
      _marketItemsSubscription?.cancel();
      _marketItemsSubscription = _firestore
          .collection('marketplace')
          .where('isSold', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      print('Error listening to market items: $e');
    }
  }

  void _postNewItem() {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to post items')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostItemSheet(
        onPost: (bondNumber, denomination, askingPrice, description, location) async {
          try {
            await _firestore.collection('marketplace').add({
              'bondNumber': bondNumber,
              'denomination': denomination,
              'askingPrice': askingPrice,
              'sellerName': user.displayName ?? 'Anonymous',
              'sellerId': user.uid,
              'sellerRating': 5.0,
              'postedDate': DateTime.now().toIso8601String(),
              'location': location,
              'description': description,
              'isSold': false,
              'createdAt': FieldValue.serverTimestamp(),
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bond posted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
      ),
    );
  }

  void _buyItem(MarketItem item) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to buy items')),
      );
      return;
    }

    if (user.uid == item.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot buy your own item')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bond: #${item.bondNumber}'),
            Text('Denomination: ${item.denomination}'),
            Text('Price: Rs. ${item.askingPrice}'),
            Text('Seller: ${item.sellerName}'),
            const SizedBox(height: 16),
            const Text('Are you sure you want to buy this bond?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Mark as sold
                await _firestore.collection('marketplace').doc(item.id).update({
                  'isSold': true,
                  'buyerId': user.uid,
                  'buyerName': user.displayName ?? 'Anonymous',
                  'soldAt': FieldValue.serverTimestamp(),
                });

                // Create transaction record
                await _firestore.collection('transactions').add({
                  'bondId': item.id,
                  'bondNumber': item.bondNumber,
                  'sellerId': item.sellerId,
                  'sellerName': item.sellerName,
                  'buyerId': user.uid,
                  'buyerName': user.displayName ?? 'Anonymous',
                  'amount': item.askingPrice,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Purchase successful! Contact seller for transfer.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('Confirm Buy'),
          ),
        ],
      ),
    );
  }

  void _editItem(MarketItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostItemSheet(
        isEdit: true,
        item: item, // ✅ Ab error nahi ayega
        onPost: (bondNumber, denomination, askingPrice, description, location) async {
          try {
            await _firestore.collection('marketplace').doc(item.id).update({
              'askingPrice': askingPrice,
              'description': description,
              'location': location,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
      ),
    );
  }

  void _deleteItem(String itemId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to remove this item from marketplace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('marketplace').doc(itemId).delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _markAsSold(String itemId) async {
    try {
      await _firestore.collection('marketplace').doc(itemId).update({
        'isSold': true,
        'soldAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as sold'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  MarketItem _parseMarketItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return MarketItem(
      id: doc.id,
      bondNumber: data['bondNumber']?.toString() ?? '',
      denomination: data['denomination']?.toString() ?? '',
      askingPrice: (data['askingPrice'] as num?)?.toDouble() ?? 0.0,
      sellerName: data['sellerName']?.toString() ?? 'Anonymous',
      sellerId: data['sellerId']?.toString() ?? '',
      sellerRating: (data['sellerRating'] as num?)?.toDouble() ?? 5.0,
      postedDate: _parseDateTime(data['postedDate']),
      location: data['location']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      isSold: data['isSold'] as bool? ?? false,
    );
  }

  DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) return DateTime.now();

      if (dateValue is Timestamp) {
        return dateValue.toDate();
      }

      if (dateValue is Map && dateValue.containsKey('_seconds')) {
        final seconds = dateValue['_seconds'] as int;
        final nanoseconds = dateValue['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + (nanoseconds ~/ 1000000));
      }

      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }

      if (dateValue is DateTime) {
        return dateValue;
      }

      return DateTime.now();
    } catch (e) {
      print('Error parsing date: $e, value: $dateValue');
      return DateTime.now();
    }
  }

  @override
  void dispose() {
    _marketItemsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bond Marketplace'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _postNewItem,
              tooltip: 'Post New Bond',
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Buy Bonds'),
              Tab(text: 'My Listings'),
            ],
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primaryColor,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        body: TabBarView(
          children: [
            // Buy Tab - All available bonds
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('marketplace')
                  .where('isSold', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
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
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to post a bond!',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!.docs
                    .map(_parseMarketItem)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildMarketItem(item);
                    },
                  ),
                );
              },
            ),

            // Sell Tab - User's listings
            StreamBuilder<QuerySnapshot>(
              stream: _auth.currentUser != null
                  ? _firestore
                  .collection('marketplace')
                  .where('sellerId', isEqualTo: _auth.currentUser!.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  : Stream<QuerySnapshot>.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (_auth.currentUser == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Please login to view your listings',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Listings',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.sell_outlined,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No bonds listed for sale',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Post your bonds to start selling',
                                style: GoogleFonts.inter(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _postNewItem,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Post First Bond'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final myItems = snapshot.data!.docs
                    .map(_parseMarketItem)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: myItems.length,
                    itemBuilder: (context, index) {
                      final item = myItems[index];
                      return _buildMyItem(item);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketItem(MarketItem item) {
    final isMyItem = _auth.currentUser?.uid == item.sellerId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(item.denomination),
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMyItem)
                  Chip(
                    label: const Text('My Item'),
                    backgroundColor: Colors.blue[50],
                    labelStyle: GoogleFonts.inter(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bond #${item.bondNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Rs. ${item.askingPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              item.description,
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
                  item.sellerName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text(
                  item.sellerRating.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  item.location,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Posted: ${_formatDate(item.postedDate)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => _buildItemDetailsDialog(item),
                      );
                    },
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isMyItem ? null : () => _buyItem(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMyItem ? Colors.grey : AppColors.primaryColor,
                    ),
                    child: Text(isMyItem ? 'Your Item' : 'Buy Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyItem(MarketItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(item.denomination),
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Chip(
                  label: Text(item.isSold ? 'SOLD' : 'AVAILABLE'),
                  backgroundColor: item.isSold ? Colors.green[50] : Colors.orange[50],
                  labelStyle: GoogleFonts.inter(
                    color: item.isSold ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bond #${item.bondNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Rs. ${item.askingPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              item.description,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  item.location,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(item.postedDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (!item.isSold)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _editItem(item),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _markAsSold(item.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                      child: const Text('Mark Sold'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteItem(item.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'This bond has been sold',
                      style: GoogleFonts.inter(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsDialog(MarketItem item) {
    return AlertDialog(
      title: Text('Bond #${item.bondNumber}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Denomination', item.denomination),
            _buildDetailRow('Asking Price', 'Rs. ${item.askingPrice.toStringAsFixed(0)}'),
            _buildDetailRow('Seller', item.sellerName),
            _buildDetailRow('Seller Rating', '${item.sellerRating.toStringAsFixed(1)}/5'),
            _buildDetailRow('Location', item.location),
            _buildDetailRow('Posted Date', _formatDate(item.postedDate)),
            const SizedBox(height: 12),
            const Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(item.description),
            const SizedBox(height: 16),
            if (_auth.currentUser?.uid != item.sellerId)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _buyItem(item);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Buy Now'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
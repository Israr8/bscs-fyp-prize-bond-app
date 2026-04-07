import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/utils/constants.dart';
import 'package:app/widgets/post_item_sheet.dart';
import 'package:app/models/market_item.dart';
import 'package:app/services/notification_service.dart';

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
      backgroundColor: Colors.transparent,
      builder: (context) => PostItemSheet(
        onPost: (bondNumber, denomination, askingPrice, description, location, sellerPhone) async {
          try {
            await _firestore.collection('marketplace').add({
              'bondNumber': bondNumber,
              'denomination': denomination,
              'askingPrice': askingPrice,
              'sellerName': user.displayName ?? 'Anonymous',
              'sellerId': user.uid,
              'sellerPhone': sellerPhone,
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

    if (item.pendingBuyerId == user.uid) {
      _showSellerContactDialog(item);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Get seller contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bond #${item.bondNumber} · ${item.denomination}'),
            const SizedBox(height: 8),
            Text('Price: Rs. ${item.askingPrice.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            Text(
              'We will show the seller phone so you can call or text. '
              'The ad stays up until they mark it sold.',
              style: GoogleFonts.inter(height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('marketplace').doc(item.id).update({
                  'pendingBuyerId': user.uid,
                  'pendingBuyerName': user.displayName ?? 'Anonymous',
                  'contactSharedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(dialogContext);
                if (!mounted) return;
                _showSellerContactDialog(item);
              } catch (e) {
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('Show number'),
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
        item: item,
        onPost: (bondNumber, denomination, askingPrice, description, location, sellerPhone) async {
          try {
            await _firestore.collection('marketplace').doc(item.id).update({
              'askingPrice': askingPrice,
              'description': description,
              'location': location,
              'sellerPhone': sellerPhone,
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

  String _denominationDigitsForMyBonds(String denomination) {
    final only = denomination.replaceAll(RegExp(r'[^\d]'), '');
    if (only.isEmpty) return '200';
    return only;
  }

  Future<void> _addPurchasedBondToBuyer({
    required String buyerUid,
    required MarketItem item,
  }) async {
    final bondNumber = item.bondNumber;
    final denomination = _denominationDigitsForMyBonds(item.denomination);
    final bondRef = _firestore
        .collection('users')
        .doc(buyerUid)
        .collection('my_bonds')
        .doc(bondNumber);

    final existing = await bondRef.get();
    if (existing.exists) {
      return;
    }

    bool isWinner = false;
    int prizeAmount = 0;
    String prizeType = '';
    String drawNumber = '';
    String drawDate = '';

    final winningSnapshot = await _firestore
        .collection('prize_bonds')
        .where('bondNumber', isEqualTo: bondNumber)
        .limit(1)
        .get();

    if (winningSnapshot.docs.isNotEmpty) {
      final winningData = winningSnapshot.docs.first.data();
      isWinner = true;
      prizeAmount = winningData['prizeAmount'] ?? 0;
      prizeType = winningData['prizeType'] ?? '';
      drawNumber = winningData['drawNumber']?.toString() ?? '';
      drawDate = winningData['drawDate']?.toString() ?? '';
    }

    await bondRef.set({
      'bondNumber': bondNumber,
      'denomination': denomination,
      'savedAt': FieldValue.serverTimestamp(),
      'isWinner': isWinner,
      'prizeAmount': prizeAmount,
      'prizeType': prizeType,
      'drawNumber': drawNumber,
      'drawDate': drawDate,
      'addedManually': false,
      'fromMarketplace': true,
      'marketplaceItemId': item.id,
      'checkedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAsSold(MarketItem item) async {
    if (item.isSold) return;

    final pendingId = item.pendingBuyerId;
    if (pendingId == null || pendingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No buyer has requested your number yet. They need to tap Buy now on this listing first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as sold'),
        content: Text(
          'Finish the sale for ${item.pendingBuyerName ?? "the buyer"}? '
          'Their bond list will update and they get a notification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final buyerName = item.pendingBuyerName ?? 'Buyer';

      await _firestore.collection('marketplace').doc(item.id).update({
        'isSold': true,
        'buyerId': pendingId,
        'buyerName': buyerName,
        'soldAt': FieldValue.serverTimestamp(),
        'pendingBuyerId': FieldValue.delete(),
        'pendingBuyerName': FieldValue.delete(),
        'contactSharedAt': FieldValue.delete(),
      });

      await _addPurchasedBondToBuyer(buyerUid: pendingId, item: item);

      final notified = await NotificationService.appendMarketplacePurchaseForBuyer(
        buyerUid: pendingId,
        bondNumber: item.bondNumber,
        marketplaceItemId: item.id,
        askingPrice: item.askingPrice,
      );

      await _firestore.collection('transactions').add({
        'bondId': item.id,
        'bondNumber': item.bondNumber,
        'sellerId': item.sellerId,
        'sellerName': item.sellerName,
        'sellerPhone': item.sellerPhone,
        'buyerId': pendingId,
        'buyerName': buyerName,
        'amount': item.askingPrice,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notified
                ? 'Done. Buyer notified.'
                : 'Sale saved. Bond is in their My Bonds, but we could not show the in-app alert. Ask them to open My Bonds.',
          ),
          backgroundColor: notified ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
      sellerPhone: data['sellerPhone']?.toString() ?? '',
      sellerRating: (data['sellerRating'] as num?)?.toDouble() ?? 5.0,
      postedDate: _parseDateTime(data['postedDate']),
      location: data['location']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      isSold: data['isSold'] as bool? ?? false,
      buyerId: data['buyerId']?.toString(),
      buyerName: data['buyerName']?.toString(),
      pendingBuyerId: data['pendingBuyerId']?.toString(),
      pendingBuyerName: data['pendingBuyerName']?.toString(),
      contactSharedAt: _parseOptionalTimestamp(data['contactSharedAt']),
    );
  }

  DateTime? _parseOptionalTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  bool _canShowSellerPhone(MarketItem item) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    if (uid == item.sellerId) return true;
    if (item.pendingBuyerId != null && uid == item.pendingBuyerId) return true;
    if (item.isSold && item.buyerId != null && uid == item.buyerId) return true;
    return false;
  }


  Future<void> _launchDial(String raw) async {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: d);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSellerContactDialog(MarketItem item) {
    final phone = item.sellerPhone.replaceAll(RegExp(r'\D'), '');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: Colors.green[700], size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('Seller contact')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Call or message the seller to pay and collect the bond. '
              'The ad stays up until they mark it sold.',
              style: GoogleFonts.inter(height: 1.4),
            ),
            const SizedBox(height: 16),
            if (phone.isNotEmpty) ...[
              Text('Seller contact', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(
                phone,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: phone));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Number copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _launchDial(phone),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'No contact number was saved on this listing. Please contact support.',
                style: GoogleFonts.inter(color: Colors.grey[700]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
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
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marketplace', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20)),
              Text(
                'Prize bonds - buy and sell',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _postNewItem,
              tooltip: 'New listing',
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.shopping_bag_outlined, size: 20), text: 'Browse'),
              Tab(icon: Icon(Icons.storefront_outlined, size: 20), text: 'My listings'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildBrowseBanner();
                      final item = items[index - 1];
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: myItems.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildSellerBanner();
                      final item = myItems[index - 1];
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

  Widget _buildBrowseBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.storefront_rounded, color: AppColors.primaryColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peer-to-peer listings',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap Buy now to see the seller phone number. The listing stays here until the seller marks it sold.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppColors.secondaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add your phone when you create a listing. Buyers only see it after they tap Buy now on your listing.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800], height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(MarketItem item, {required bool isSellerView}) {
    final show = _canShowSellerPhone(item) || isSellerView;
    final phone = item.sellerPhone.replaceAll(RegExp(r'\D'), '');

    if (isSellerView && phone.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange[800]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add a contact number (tap Edit) so buyers can reach you.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      );
    }

    if (show && phone.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, size: 20, color: Colors.green[800]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSellerView ? 'Your contact' : 'Seller contact',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700]),
                  ),
                  SelectableText(
                    phone,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!isSellerView)
              IconButton(
                onPressed: () => _launchDial(phone),
                icon: const Icon(Icons.call),
                tooltip: 'Call',
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap Buy now to see the seller phone number',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketItem(MarketItem item) {
    final isMyItem = _auth.currentUser?.uid == item.sellerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.denomination,
                    style: GoogleFonts.inter(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isMyItem)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Your listing',
                      style: GoogleFonts.inter(color: Colors.blue[800], fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bond #${item.bondNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Rs. ${item.askingPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),

            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                style: GoogleFonts.inter(
                  color: Colors.grey[700],
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.sellerName,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.star_rounded, size: 18, color: Colors.amber[700]),
                Text(
                  item.sellerRating.toStringAsFixed(1),
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.location,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            _buildContactRow(item, isSellerView: isMyItem),

            const SizedBox(height: 8),

            Text(
              'Posted ${_formatDate(item.postedDate)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 14),

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
                    child: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isMyItem ? null : () => _buyItem(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: isMyItem ? Colors.grey : AppColors.primaryColor,
                    ),
                    child: Text(
                      isMyItem
                          ? 'Your listing'
                          : (_auth.currentUser?.uid == item.pendingBuyerId
                              ? 'View contact'
                              : 'Buy now'),
                    ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.denomination,
                    style: GoogleFonts.inter(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isSold ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.isSold ? 'SOLD' : 'LIVE',
                    style: GoogleFonts.inter(
                      color: item.isSold ? Colors.green[800] : Colors.orange[900],
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bond #${item.bondNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Rs. ${item.askingPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),

            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                style: GoogleFonts.inter(color: Colors.grey[700], height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.location,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(item.postedDate),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

            _buildContactRow(item, isSellerView: true),

            if (!item.isSold &&
                item.pendingBuyerName != null &&
                item.pendingBuyerName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_search_rounded, size: 20, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buyer who requested contact: ${item.pendingBuyerName}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (item.isSold && item.buyerName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Buyer: ${item.buyerName}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.green[900], fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 12),

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
                      onPressed: () => _markAsSold(item),
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
    final isSeller = _auth.currentUser?.uid == item.sellerId;
    final showPhone = _canShowSellerPhone(item) || isSeller;
    final phone = item.sellerPhone.replaceAll(RegExp(r'\D'), '');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Bond #${item.bondNumber}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Denomination', item.denomination),
            _buildDetailRow('Asking price', 'Rs. ${item.askingPrice.toStringAsFixed(0)}'),
            _buildDetailRow('Seller', item.sellerName),
            _buildDetailRow('Rating', '${item.sellerRating.toStringAsFixed(1)}/5'),
            _buildDetailRow('Location', item.location),
            _buildDetailRow('Posted', _formatDate(item.postedDate)),
            const SizedBox(height: 12),
            if (showPhone && phone.isNotEmpty) ...[
              Text('Contact', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SelectableText(
                phone,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  TextButton.icon(
                    onPressed: () => _launchDial(phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                  ),
                ],
              ),
            ] else if (!isSeller) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap Buy now to see the seller phone number.',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Description', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(item.description, style: GoogleFonts.inter(height: 1.35)),
            ],
            const SizedBox(height: 16),
            if (!isSeller)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _buyItem(item);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Buy now'),
                ),
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
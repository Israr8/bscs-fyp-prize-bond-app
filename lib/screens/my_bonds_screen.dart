// lib/screens/my_bonds_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/widgets/bond_item.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/screens/scan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyBondsScreen extends StatefulWidget {
  const MyBondsScreen({super.key});

  @override
  State<MyBondsScreen> createState() => _MyBondsScreenState();
}

class _MyBondsScreenState extends State<MyBondsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _myBonds = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'winning', 'non-winning'
  int _totalBonds = 0;
  int _winningBonds = 0;
  double _totalPrize = 0;
  StreamSubscription? _drawsSubscription;

  final List<String> _denominations = [
    '200',
    '750',
    '1500',
    '7500',
    '15000',
    '25000',
    '40000',
  ];

  @override
  void initState() {
    super.initState();

    // Pehle bonds load hon gye -- phir draws check khon gye
    _initializeApp();
  }


  @override
  void dispose() {
    _drawsSubscription?.cancel();
    super.dispose();
  }
  Future<void> _initializeApp() async {
    //  Load bonds first
    await _loadMyBonds();

    _setupDrawsListener();

    // Immediately check all draws once
    await _checkAllDrawsOnce();
  }

  Future<void> _checkAllDrawsOnce() async {
    try {
      debugPrint('Checking draws on startup...');

      final snapshot = await _firestore
          .collection('draws')
          .orderBy('drawDate', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint('Found ${snapshot.docs.length} draws to check');

        for (final draw in snapshot.docs) {
          await _checkForNewDrawResults(draw);
        }
      }
    } catch (e) {
      debugPrint('Error checking draws on startup: $e');
    }
  }

  void _setupDrawsListener() {
    // Cancel previous subscription if exists
    _drawsSubscription?.cancel();

    debugPrint('Setting up draws listener with ${_myBonds.length} bonds loaded');

    _drawsSubscription = _firestore
        .collection('draws')
        .orderBy('drawDate', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        debugPrint(' ${snapshot.docs.length} draws found for checking');

        // bonds load honay do
        if (_myBonds.isEmpty) {
          debugPrint('No bonds to check, reloading...');
          await _loadMyBonds();
        }

        // Process each draw
        for (final draw in snapshot.docs) {
          await _checkForNewDrawResults(draw);
        }
      }
    }, onError: (error) {
      debugPrint('Draws listener error: $error');
    });
  }

  Future<void> _checkForNewDrawResults(QueryDocumentSnapshot latestDraw) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final drawData = latestDraw.data() as Map<String, dynamic>;
      final drawId = latestDraw.id;
      final drawDenomination = drawData['denomination']?.toString() ?? '';

      debugPrint('=== DRAW DATA DEBUG ===');
      debugPrint('Draw Number: ${drawData['drawNumber']}');
      debugPrint('Draw Denomination: $drawDenomination');
      debugPrint('First Prize: ${drawData['firstPrize']}');
      debugPrint('Second Prize: ${drawData['secondPrize']}');
      debugPrint('Third Prize: ${drawData['thirdPrize']}');
      debugPrint('Third Prize Type: ${drawData['thirdPrize'].runtimeType}');
      debugPrint('=== END DEBUG ===');

      final prefs = await SharedPreferences.getInstance();
      final lastProcessedDraw = prefs.getString('last_processed_draw');

      if (lastProcessedDraw == drawId) {
        return; // Already processed
      }

      debugPrint('Checking draw: ${drawData['drawNumber']}, Denomination: $drawDenomination');

      // Process each bond
      bool anyUpdates = false;
      for (var bond in _myBonds) {
        final bondNumber = bond['bondNumber']?.toString().trim();
        final bondDenomination = bond['denomination']?.toString() ?? '';

        if (bondNumber == null) continue;

        // bond denomination draw se match honi chahiye
        if (bondDenomination != drawDenomination) {
          debugPrint('Skipping bond $bondNumber - Denomination mismatch: $bondDenomination vs $drawDenomination');
          continue;
        }

        debugPrint('Checking bond: $bondNumber (Denomination: $bondDenomination)');

        bool isWinner = false;
        String prizeType = '';
        int prizeAmount = 0;

        String firstPrizeStr = drawData['firstPrize']?.toString().trim() ?? '';
        firstPrizeStr = firstPrizeStr.replaceAll(',', '').replaceAll(' ', '');

        if (firstPrizeStr == bondNumber) {
          isWinner = true;
          prizeType = 'First Prize';
          prizeAmount = getPrizeAmount('first', bondDenomination);
          debugPrint('Bond $bondNumber is FIRST PRIZE winner');
        }

        if (!isWinner) {
          final secondPrizeData = drawData['secondPrize'];
          if (secondPrizeData is List) {
            for (var prize in secondPrizeData) {
              String prizeStr = prize?.toString().trim() ?? '';
              prizeStr = prizeStr.replaceAll(',', '').replaceAll(' ', '');

              if (prizeStr == bondNumber) {
                isWinner = true;
                prizeType = 'Second Prize';
                prizeAmount = getPrizeAmount('second', bondDenomination);
                debugPrint('Bond $bondNumber is SECOND PRIZE winner');
                break;
              }
            }
          } else if (secondPrizeData is String) {
            String prizeStr = secondPrizeData.trim();
            prizeStr = prizeStr.replaceAll(',', '').replaceAll(' ', '');

            if (prizeStr == bondNumber) {
              isWinner = true;
              prizeType = 'Second Prize';
              prizeAmount = getPrizeAmount('second', bondDenomination);
              debugPrint('Bond $bondNumber is SECOND PRIZE winner (string)');
            }
          }
        }

        if (!isWinner) {
          final thirdPrizeData = drawData['thirdPrize'];
          debugPrint('Checking third prize for $bondNumber');
          debugPrint('Third prize data: $thirdPrizeData');
          debugPrint('Type: ${thirdPrizeData.runtimeType}');

          if (thirdPrizeData is List) {
            debugPrint('Third prize is List with ${thirdPrizeData.length} items');
            for (var i = 0; i < thirdPrizeData.length; i++) {
              var prize = thirdPrizeData[i];
              debugPrint('Index $i: $prize');

              if (prize != null) {
                String prizeStr = prize.toString().trim();
                prizeStr = prizeStr.replaceAll(',', '').replaceAll(' ', '');

                debugPrint('  Cleaned: $prizeStr');
                debugPrint('  Comparing with: $bondNumber');

                if (prizeStr == bondNumber) {
                  isWinner = true;
                  prizeType = 'Third Prize';
                  prizeAmount = getPrizeAmount('third', bondDenomination);
                  debugPrint('Bond $bondNumber is THIRD PRIZE winner at index $i');
                  break;
                }
              }
            }
          } else if (thirdPrizeData is String) {
            debugPrint('Third prize is String: $thirdPrizeData');
            String prizeStr = thirdPrizeData.trim();
            prizeStr = prizeStr.replaceAll(',', '').replaceAll(' ', '');

            if (prizeStr.contains(' ')) {
              // Space separated multiple prizes
              List<String> prizes = prizeStr.split(RegExp(r'\s+'));
              debugPrint('Split prizes: $prizes');

              for (var prize in prizes) {
                if (prize.trim() == bondNumber) {
                  isWinner = true;
                  prizeType = 'Third Prize';
                  prizeAmount = getPrizeAmount('third', bondDenomination);
                  debugPrint('Bond $bondNumber is THIRD PRIZE winner in string');
                  break;
                }
              }
            } else {
              // Single prize
              if (prizeStr == bondNumber) {
                isWinner = true;
                prizeType = 'Third Prize';
                prizeAmount = getPrizeAmount('third', bondDenomination);
                debugPrint('Bond $bondNumber is THIRD PRIZE winner (single)');
              }
            }
          }
        }

        // If bond is winner and not already marked as winner
        if (isWinner && bond['isWinner'] != true) {
          anyUpdates = true;

          debugPrint('Updating bond $bondNumber as winner: $prizeType');

          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('my_bonds')
              .doc(bond['id'])
              .update({
            'isWinner': true,
            'prizeAmount': prizeAmount,
            'prizeType': prizeType,
            'drawNumber': drawData['drawNumber'],
            'drawDate': drawData['drawDate'],
            'checkedAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Send notification
          await NotificationService.showNotification(
            title: 'Congratulations! Your bond won!',
            body: 'Bond #$bondNumber won $prizeType in ${drawData['drawNumber']}',
          );

          // Also save to Firestore notifications
          await _firestore
              .collection('notifications')
              .doc(user.uid)
              .collection('user_notifications')
              .add({
            'title': 'Bond Prize Winner!',
            'body': 'Your bond #$bondNumber won $prizeType in ${drawData['drawNumber']}',
            'type': 'WINNING_BOND',
            'bondNumber': bondNumber,
            'drawNumber': drawData['drawNumber'],
            'prizeAmount': prizeAmount,
            'prizeType': prizeType,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else if (isWinner) {
          debugPrint('Bond $bondNumber already marked as winner');
        } else {
          debugPrint('Bond $bondNumber is not a winner in this draw');
        }
      }

      await prefs.setString('last_processed_draw', drawId);

      // Reload bonds to show updated status
      if (anyUpdates) {
        await _loadMyBonds();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draw results checked. Some bonds updated!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        debugPrint('📊 No updates found for any bonds');
      }

    } catch (e) {
      debugPrint('Error checking draw results: $e');
    }
  }

  int getPrizeAmount(String prizeType, String denomination) {
    int denom = int.tryParse(denomination) ?? 200;

    switch (prizeType) {
      case 'first':
        return denom * 7500; // First prize formula

      case 'second':
        return denom * 2500; // Second prize formula

      case 'third':
        return denom * 6; // Third prize formula

      default:
        return 0;
    }
  }
  Future<void> _loadMyBonds() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('User is null, cannot load bonds');
        return;
      }

      debugPrint('Loading bonds for user: ${user.uid}');

      setState(() {
        _isLoading = true;
      });

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_bonds')
          .orderBy('savedAt', descending: true)
          .get();

      debugPrint('Loaded ${snapshot.docs.length} bonds from Firestore');

      if (snapshot.docs.isEmpty) {
        debugPrint('No bonds found in Firestore');
      }

      _myBonds = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('Bond: ${data['bondNumber']}, isWinner: ${data['isWinner']}');
        _myBonds.add({
          'id': doc.id,
          ...data,
        });
      }

      // Calculate statistics
      _calculateStats();

    } catch (e) {
      debugPrint('Error loading bonds: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateStats() {
    _totalBonds = _myBonds.length;
    _winningBonds = _myBonds.where((bond) => bond['isWinner'] == true).length;
    _totalPrize = _myBonds.fold(0.0, (sum, bond) {
      if (bond['isWinner'] == true) {
        return sum + (bond['prizeAmount'] ?? 0);
      }
      return sum;
    });
  }

  List<Map<String, dynamic>> _getFilteredBonds() {
    if (_filterStatus == 'all') return _myBonds;
    if (_filterStatus == 'winning') {
      return _myBonds.where((bond) => bond['isWinner'] == true).toList();
    }
    if (_filterStatus == 'non-winning') {
      return _myBonds.where((bond) => bond['isWinner'] != true).toList();
    }
    return _myBonds;
  }

  void _addNewBond() {
    TextEditingController bondNumberController = TextEditingController();
    String selectedDenomination = '200';
    DateTime purchaseDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Bond Manually',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: bondNumberController,
                    decoration: InputDecoration(
                      labelText: 'Bond Number',
                      hintText: 'Enter 6-digit bond number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter bond number';
                      }
                      if (value.length != 6) {
                        return 'Bond number must be 6 digits';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedDenomination,
                    decoration: InputDecoration(
                      labelText: 'Denomination',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _denominations
                        .map<DropdownMenuItem<String>>((denom) => DropdownMenuItem<String>(
                      value: denom,
                      child: Text('Rs. $denom Prize Bond'),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedDenomination = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (bondNumberController.text.isNotEmpty && bondNumberController.text.length == 6) {
                              await _saveManualBond(
                                bondNumberController.text,
                                selectedDenomination,
                                purchaseDate,
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid 6-digit bond number'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                          ),
                          child: const Text('Save Bond'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveManualBond(String bondNumber, String denomination, DateTime savedDate) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      setState(() {
        _isLoading = true;
      });

      // First check if bond already exists
      final existingSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_bonds')
          .where('bondNumber', isEqualTo: bondNumber)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This bond is already saved'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
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

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_bonds')
          .doc(bondNumber)
          .set({
        'bondNumber': bondNumber,
        'denomination': denomination,
        'savedAt': Timestamp.fromDate(savedDate),
        'isWinner': isWinner,
        'prizeAmount': prizeAmount,
        'prizeType': prizeType,
        'drawNumber': drawNumber,
        'drawDate': drawDate,
        'addedManually': true,
        'checkedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bond #$bondNumber saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadMyBonds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving bond: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBond(String bondId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Bond'),
          content: const Text('Are you sure you want to delete this bond?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ?? false;

      if (confirm) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('my_bonds')
            .doc(bondId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bond deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadMyBonds();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting bond: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkAllBonds() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      for (var bond in _myBonds) {
        final bondNumber = bond['bondNumber'];
        if (bondNumber == null) continue;

        final resultSnapshot = await _firestore
            .collection('prize_bonds')
            .where('bondNumber', isEqualTo: bondNumber.toString())
            .limit(1)
            .get();

        if (resultSnapshot.docs.isNotEmpty) {
          final winningData = resultSnapshot.docs.first.data();
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('my_bonds')
              .doc(bond['id'])
              .update({
            'isWinner': true,
            'prizeAmount': winningData['prizeAmount'],
            'prizeType': winningData['prizeType'],
            'drawNumber': winningData['drawNumber'],
            'drawDate': winningData['drawDate'],
            'checkedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('my_bonds')
              .doc(bond['id'])
              .update({
            'isWinner': false,
            'checkedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All bonds checked successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadMyBonds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking bonds: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBonds = _getFilteredBonds();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bonds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewBond,
            tooltip: 'Add bond manually',
          ),
          if (_myBonds.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'check_all') {
                  _checkAllBonds();
                } else if (value == 'refresh') {
                  _loadMyBonds();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'check_all',
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20),
                      SizedBox(width: 8),
                      Text('Check All Bonds'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const ScanScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Statistics Card
          if (_myBonds.isNotEmpty)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Bond Portfolio',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total', '$_totalBonds', Icons.list),
                        _buildStatItem('Winning', '$_winningBonds', Icons.emoji_events),
                        _buildStatItem('Prize', 'Rs. ${NumberFormat('#,##0').format(_totalPrize)}', Icons.money),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Filter Chips
          if (_myBonds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All ($_totalBonds)', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Winning ($_winningBonds)', 'winning'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Non-Winning (${_totalBonds - _winningBonds})', 'non-winning'),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Bonds List
          Expanded(
            child: filteredBonds.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadMyBonds,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredBonds.length,
                itemBuilder: (context, index) {
                  final bond = filteredBonds[index];
                  return BondItem(
                    bondNumber: bond['bondNumber']?.toString() ?? 'N/A',
                    denomination: 'Rs. ${bond['denomination'] ?? '200'} Prize Bond',
                    savedDate: (bond['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    isWinner: bond['isWinner'] == true,
                    prizeAmount: bond['prizeAmount'],
                    onTap: () {
                      // View bond details
                      _viewBondDetails(bond);
                    },
                    onDelete: () => _deleteBond(bond['id']),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewBondDetails(Map<String, dynamic> bond) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bond #${bond['bondNumber']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Bond Number', bond['bondNumber']?.toString() ?? 'N/A'),
              _buildDetailRow('Denomination', 'Rs. ${bond['denomination'] ?? '200'}'),
              _buildDetailRow('Saved Date', DateFormat('dd MMM yyyy').format(
                (bond['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              )),
              _buildDetailRow('Status', bond['isWinner'] == true ? 'Winner' : 'Not Winning'),

              if (bond['isWinner'] == true) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Prize Amount', 'Rs. ${NumberFormat('#,##0').format(bond['prizeAmount'] ?? 0)}'),
                if (bond['prizeType'] != null) _buildDetailRow('Prize Type', bond['prizeType'].toString()),
                if (bond['drawNumber'] != null) _buildDetailRow('Draw Number', bond['drawNumber'].toString()),
                if (bond['drawDate'] != null) _buildDetailRow('Draw Date', bond['drawDate'].toString()),
              ],

              if (bond['addedManually'] == true)
                _buildDetailRow('Added', 'Manually'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (bond['isWinner'] != true)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _checkSingleBond(bond['id'], bond['bondNumber'].toString());
              },
              child: const Text('Check Now'),
            ),
        ],
      ),
    );
  }

  Future<void> _checkSingleBond(String bondId, String bondNumber) async {
    try {
      final resultSnapshot = await _firestore
          .collection('prize_bonds')
          .where('bondNumber', isEqualTo: bondNumber)
          .limit(1)
          .get();

      final user = _auth.currentUser;
      if (user == null) return;

      if (resultSnapshot.docs.isNotEmpty) {
        final winningData = resultSnapshot.docs.first.data();
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('my_bonds')
            .doc(bondId)
            .update({
          'isWinner': true,
          'prizeAmount': winningData['prizeAmount'],
          'prizeType': winningData['prizeType'],
          'drawNumber': winningData['drawNumber'],
          'drawDate': winningData['drawDate'],
          'checkedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Congratulations! This bond is a winner!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('my_bonds')
            .doc(bondId)
            .update({
          'isWinner': false,
          'checkedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This bond is not a winner. Better luck next time!'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      await _loadMyBonds();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking bond: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filterStatus == value,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppColors.primaryColor,
      labelStyle: TextStyle(
        color: _filterStatus == value ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wallet_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No bonds saved yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add bonds manually or scan them',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _addNewBond,
                icon: const Icon(Icons.add),
                label: const Text('Add Bond Manually'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const ScanScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan Bond'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
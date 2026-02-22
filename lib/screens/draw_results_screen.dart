import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DrawResultsScreen extends StatefulWidget {
  const DrawResultsScreen({super.key});

  @override
  State<DrawResultsScreen> createState() => _DrawResultsScreenState();
}

class _DrawResultsScreenState extends State<DrawResultsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<QueryDocumentSnapshot> _draws = [];
  List<String> _drawDates = ['All']; // Will be populated from database
  List<String> _denominations = ['Select Denomination', '100', '200', '750', '1500', '25000', '40000'];

  String _selectedDenomination = 'Select Denomination';
  String _selectedDrawDate = 'All';
  bool _isLoading = true;
  bool _isSearching = false;
  String? _lastDrawError;
  bool _showDenominationDropdown = false;
  bool _showDateDropdown = false;

  // New variables for search type
  String _searchType = 'single'; // 'single', 'series', 'multiple'
  final TextEditingController _startSeriesController = TextEditingController();
  final TextEditingController _endSeriesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDrawResults();
    _loadDrawDates();
  }

  Future<void> _loadDrawDates() async {
    try {
      Query query = _firestore
          .collection('draws')
          .orderBy('drawDate', descending: true);

      final snapshot = await query.get();

      Set<String> uniqueDates = {'All'};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final drawDate = data['drawDate'];

        if (drawDate is Timestamp) {
          final dateStr = DateFormat('dd MMMM, yyyy').format(drawDate.toDate());
          uniqueDates.add(dateStr);
        }
      }

      setState(() {
        _drawDates = uniqueDates.toList();
      });
    } catch (e) {
      debugPrint('Error loading draw dates: $e');
    }
  }

  Future<void> _loadDrawResults() async {
    try {
      setState(() {
        _isLoading = true;
        _lastDrawError = null;
      });

      Query query = _firestore
          .collection('draws')
          .orderBy('drawDate', descending: true)
          .limit(50);

      // Apply denomination filter
      if (_selectedDenomination != 'Select Denomination' && _selectedDenomination != 'All') {
        query = query.where('denomination', isEqualTo: _selectedDenomination);
      }

      // Apply date filter
      if (_selectedDrawDate != 'All') {
        try {
          final date = DateFormat('dd MMMM, yyyy').parse(_selectedDrawDate);
          final startOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
          final endOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day, 23, 59, 59));

          query = query
              .where('drawDate', isGreaterThanOrEqualTo: startOfDay)
              .where('drawDate', isLessThanOrEqualTo: endOfDay);
        } catch (e) {
          debugPrint('Error parsing date: $e');
        }
      }

      final snapshot = await query.get();

      setState(() {
        _draws = snapshot.docs;
      });

    } catch (e) {
      debugPrint('Error loading draws: $e');
      setState(() {
        _lastDrawError = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Modified search function to handle all types
  Future<void> _checkBondInDraws() async {
    // Check if denomination is selected
    if (_selectedDenomination == 'Select Denomination') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a denomination first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<String> bondNumbers = [];

      if (_searchType == 'single') {
        final bondNumber = _searchController.text.trim();
        if (bondNumber.length != 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter exactly 6 digit bond number'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        bondNumbers.add(bondNumber);
      }
      else if (_searchType == 'series') {
        final start = _startSeriesController.text.trim();
        final end = _endSeriesController.text.trim();

        if (start.length != 6 || end.length != 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter 6 digit numbers for series'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final startNum = int.tryParse(start);
        final endNum = int.tryParse(end);

        if (startNum == null || endNum == null || endNum <= startNum) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid series range'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Generate series (limit to reasonable range)
        final range = endNum - startNum;
        if (range > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Series range too large (max 100 numbers)'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        for (int i = startNum; i <= endNum; i++) {
          bondNumbers.add(i.toString().padLeft(6, '0'));
        }
      }
      else if (_searchType == 'multiple') {
        final input = _searchController.text.trim();
        final numbers = input.split(RegExp(r'[,，\s]+'));

        for (var num in numbers) {
          num = num.trim();
          if (num.length == 6) {
            bondNumbers.add(num);
          }
        }

        if (bondNumbers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter valid 6 digit numbers'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (bondNumbers.length > 20) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 20 numbers allowed'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      Query query = _firestore
          .collection('draws')
          .orderBy('drawDate', descending: true)
          .limit(50);

      // Apply denomination filter for search
      if (_selectedDenomination != 'Select Denomination' && _selectedDenomination != 'All') {
        query = query.where('denomination', isEqualTo: _selectedDenomination);
      }

      final drawsSnapshot = await query.get();

      List<Map<String, dynamic>> winningBonds = [];

      for (final bondNumber in bondNumbers) {
        for (final draw in drawsSnapshot.docs) {
          final data = draw.data() as Map<String, dynamic>;
          final drawId = draw.id;

          String? prizeType;

          // Check first prize
          final firstPrize = data['firstPrize']?.toString().trim();
          if (firstPrize == bondNumber) {
            prizeType = 'First Prize';
          }

          // Check second prizes
          if (prizeType == null) {
            final secondPrizes = data['secondPrize'];
            if (secondPrizes is List) {
              for (var prize in secondPrizes) {
                if (prize.toString().trim() == bondNumber) {
                  prizeType = 'Second Prize';
                  break;
                }
              }
            }
          }

          // Check third prizes
          if (prizeType == null) {
            final thirdPrizeData = data['thirdPrize'];
            if (thirdPrizeData != null) {
              if (thirdPrizeData is List) {
                for (var prize in thirdPrizeData) {
                  if (prize.toString().trim() == bondNumber) {
                    prizeType = 'Third Prize';
                    break;
                  }
                }
              } else if (thirdPrizeData is String) {
                final numbers = thirdPrizeData.split(RegExp(r'[ ,]+'));
                for (final num in numbers) {
                  if (num.trim() == bondNumber) {
                    prizeType = 'Third Prize';
                    break;
                  }
                }
              }
            }
          }

          // Check consolation prizes
          if (prizeType == null) {
            final consolationPrizeData = data['consolationPrize'];
            if (consolationPrizeData != null) {
              if (consolationPrizeData is List) {
                for (var prize in consolationPrizeData) {
                  if (prize.toString().trim() == bondNumber) {
                    prizeType = 'Consolation Prize';
                    break;
                  }
                }
              }
            }
          }

          if (prizeType != null) {
            winningBonds.add({
              'bondNumber': bondNumber,
              'drawData': {...data, 'id': drawId},
              'prizeType': prizeType,
            });
            break; // Stop checking this bond in other draws
          }
        }
      }

      if (winningBonds.isNotEmpty) {
        _showMultiResultDialog(winningBonds);
      } else {
        _showNoResultDialog();
      }

    } catch (e) {
      debugPrint('Error checking bond: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showMultiResultDialog(List<Map<String, dynamic>> winningBonds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          winningBonds.length == 1 ? 'Congratulations!' : 'Multiple Winners Found!',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Winning Bonds: ${winningBonds.length}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),

              ...winningBonds.map((bond) {
                final data = bond['drawData'];
                final prizeType = bond['prizeType'];
                final bondNumber = bond['bondNumber'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$prizeType',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Rs. ${_getPrizeAmount(data['denomination'], prizeType)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Bond: $bondNumber'),
                      Text('Draw #${data['drawNumber'] ?? 'N/A'}'),
                      Text('Date: ${_formatDate(data['drawDate'])}'),
                      Text('Denomination: Rs. ${data['denomination'] ?? '0'}'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_auth.currentUser != null && winningBonds.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveMultipleBonds(winningBonds);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Save All (${winningBonds.length})'),
            ),
        ],
      ),
    );
  }

  void _showNoResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Winners Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.grey, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No winning bonds found',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDenomination == 'All'
                  ? 'Not found in recent 50 draws'
                  : 'Not found in recent ${_selectedDenomination} draws',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMultipleBonds(List<Map<String, dynamic>> winningBonds) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(user.uid);
      final bondsRef = userRef.collection('my_bonds');

      for (final bond in winningBonds) {
        final bondNumber = bond['bondNumber'];
        final drawData = bond['drawData'];
        final prizeType = bond['prizeType'];

        final docRef = bondsRef.doc(bondNumber);

        batch.set(docRef, {
          'bondNumber': bondNumber,
          'denomination': drawData['denomination'],
          'isWinner': true,
          'prizeType': prizeType,
          'drawNumber': drawData['drawNumber'],
          'drawDate': drawData['drawDate'],
          'city': drawData['city'],
          'savedAt': FieldValue.serverTimestamp(),
          'prizeAmount': _getPrizeAmount(drawData['denomination'], prizeType),
        }, SetOptions(merge: true));
      }

      batch.update(userRef, {
        'bondsCount': FieldValue.increment(winningBonds.length),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${winningBonds.length} winning bonds saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _getPrizeAmount(String denomination, String prizeType) {
    final denom = int.tryParse(denomination) ?? 0;

    if (prizeType == 'First Prize') {
      return denom * 7500;
    } else if (prizeType == 'Second Prize') {
      return denom * 2500;
    } else if (prizeType == 'Third Prize') {
      return denom * 6;
    } else if (prizeType == 'Consolation Prize') {
      return denom * 3;
    }

    return 0;
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('dd MMM yyyy').format(date.toDate());
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  // Build denomination dropdown
  Widget _buildDenominationDropdown() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showDenominationDropdown = !_showDenominationDropdown;
                _showDateDropdown = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDenomination,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: _selectedDenomination == 'Select Denomination'
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                  Icon(
                    _showDenominationDropdown
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (_showDenominationDropdown)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: _denominations.map((denom) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDenomination = denom;
                        _showDenominationDropdown = false;
                        _selectedDrawDate = 'All'; // Reset date when denomination changes
                        _loadDrawResults();
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: denom == _denominations.last
                              ? BorderSide.none
                              : BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Text(
                        denom == 'Select Denomination' ? 'Select Denomination' : 'Rs. $denom',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: _selectedDenomination == denom
                              ? AppColors.primaryColor
                              : Colors.black,
                          fontWeight: _selectedDenomination == denom
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Build draw date dropdown
  Widget _buildDateDropdown() {
    return Visibility(
      visible: _selectedDenomination != 'Select Denomination',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showDateDropdown = !_showDateDropdown;
                  _showDenominationDropdown = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDrawDate,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Icon(
                      _showDateDropdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),

            if (_showDateDropdown)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _drawDates.map((date) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDrawDate = date;
                            _showDateDropdown = false;
                            _loadDrawResults();
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: date == _drawDates.last
                                  ? BorderSide.none
                                  : BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Text(
                            date,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _selectedDrawDate == date
                                  ? AppColors.primaryColor
                                  : Colors.black,
                              fontWeight: _selectedDrawDate == date
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build the search section based on type
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Column(
        children: [
          // Search type selector
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSearchTypeButton('Single', 'single', Icons.search),
                _buildSearchTypeButton('Series', 'series', Icons.list),
                _buildSearchTypeButton('Multiple', 'multiple', Icons.format_list_numbered),
              ],
            ),
          ),

          // Search input based on type
          if (_searchType == 'single')
            _buildSingleSearch()
          else if (_searchType == 'series')
            _buildSeriesSearch()
          else if (_searchType == 'multiple')
              _buildMultipleSearch(),

          const SizedBox(height: 12),

          // Search button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _checkBondInDraws,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSearching
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8),
                  Text(
                    _searchType == 'single'
                        ? 'Check Single Bond'
                        : _searchType == 'series'
                        ? 'Check Series'
                        : 'Check Multiple Bonds',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTypeButton(String text, String type, IconData icon) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _searchType == type ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _searchType == type ? AppColors.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: _searchType == type ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: _searchType == type ? Colors.white : Colors.black,
                fontWeight: _searchType == type ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSearch() {
    return TextFormField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Enter 6 digit bond number',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.confirmation_number),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => _searchController.clear(),
        ),
      ),
      keyboardType: TextInputType.number,
      maxLength: 6,
    );
  }

  Widget _buildSeriesSearch() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startSeriesController,
                decoration: InputDecoration(
                  hintText: 'Start (6 digits)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.arrow_right_alt),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _endSeriesController,
                decoration: InputDecoration(
                  hintText: 'End (6 digits)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.flag),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Example: 314151 to 314159 (max 100 numbers)',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMultipleSearch() {
    return Column(
      children: [
        TextFormField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter numbers separated by commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.format_list_numbered),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
          ),
          maxLines: 3,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 8),
        Text(
          'Example: 123456, 234567, 345678 (max 20 numbers)',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrawResults,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top dropdowns (Denomination and Date)
          _buildDenominationDropdown(),
          _buildDateDropdown(),

          // Search Section (only visible after denomination is selected)
          if (_selectedDenomination != 'Select Denomination')
            _buildSearchSection(),

          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lastDrawError != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load draws',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastDrawError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDrawResults,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : _draws.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.list_alt_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No draw results available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDenomination == 'All'
                        ? 'Check back later'
                        : 'No ${_selectedDenomination} draws',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadDrawResults,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _draws.length,
                itemBuilder: (context, index) {
                  return _buildDrawCard(_draws[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final drawDate = data['drawDate'] is Timestamp
        ? (data['drawDate'] as Timestamp).toDate()
        : DateTime.now();

    final secondPrizes = data['secondPrize'] is List
        ? (data['secondPrize'] as List)
        : [];
    final thirdPrizes = data['thirdPrize'] is List
        ? (data['thirdPrize'] as List)
        : [];

    final totalPrizes = 1 + secondPrizes.length + thirdPrizes.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
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
                  label: Text('Rs. ${data['denomination'] ?? '0'}'),
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                  labelStyle: GoogleFonts.inter(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Draw #${data['drawNumber'] ?? 'N/A'}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              DateFormat('dd MMM yyyy').format(drawDate),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  data['city'] ?? 'N/A',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.emoji_events, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$totalPrizes prizes',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'First Prize: ${data['firstPrize'] ?? 'N/A'}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (secondPrizes.isNotEmpty)
                    Text(
                      'Second Prize (${secondPrizes.length}): ${secondPrizes.take(2).join(', ')}${secondPrizes.length > 2 ? '...' : ''}',
                      style: GoogleFonts.inter(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewFullResults(doc),
                    child: const Text('View All Winners'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _shareDrawResults(data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewFullResults(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final secondPrizes = data['secondPrize'] is List ? (data['secondPrize'] as List) : [];
    final thirdPrizes = data['thirdPrize'] is List ? (data['thirdPrize'] as List) : [];
    final consolationPrizes = data['consolationPrize'] is List ? (data['consolationPrize'] as List) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draw #${data['drawNumber']}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Rs. ${data['denomination']} • ${data['city']}',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPrizeSection(
                      'First Prize (1 Winner)',
                      [data['firstPrize'] ?? 'N/A'],
                    ),
                    const SizedBox(height: 20),
                    _buildPrizeSection(
                      'Second Prize (${secondPrizes.length} Winners)',
                      secondPrizes,
                    ),
                    const SizedBox(height: 20),
                    _buildPrizeSection(
                      '🥉 Third Prize (${thirdPrizes.length} Winners)',
                      thirdPrizes,
                    ),
                    if (consolationPrizes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildPrizeSection(
                        '🎗️ Consolation Prize (${consolationPrizes.length} Winners)',
                        consolationPrizes,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeSection(String title, List<dynamic> prizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prizes.map((prize) {
              return Chip(
                label: Text(prize.toString()),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _shareDrawResults(Map<String, dynamic> data) {
    final shareText =
        'Prize Bond Draw Results\n'
        'Draw #${data['drawNumber']}\n'
        'Date: ${_formatDate(data['drawDate'])}\n'
        'City: ${data['city']}\n'
        'Denomination: Rs. ${data['denomination']}\n'
        'First Prize: ${data['firstPrize']}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share: $shareText'),
      ),
    );
  }
}
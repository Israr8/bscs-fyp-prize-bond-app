import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_file/open_file.dart';

class DrawListsScreen extends StatefulWidget {
  const DrawListsScreen({super.key});

  @override
  State<DrawListsScreen> createState() => _DrawListsScreenState();
}

class _DrawListsScreenState extends State<DrawListsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedDenomination;
  String? _selectedDrawNumber;
  Map<String, dynamic>? _drawDetails;
  List<String> _winningNumbers = [];
  bool _isDownloading = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Lists'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedDenomination == null) {
      return _buildDenominationSelection();
    } else if (_selectedDrawNumber == null) {
      return _buildDrawNumberSelection();
    } else {
      return _buildDrawDetails();
    }
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'N/A';
    if (dateField is Timestamp) {
      final dateTime = dateField.toDate();
      return '${dateTime.day}-${dateTime.month}-${dateTime.year}';
    } else if (dateField is String) {
      return dateField;
    }
    return dateField.toString();
  }

  String _formatArrayDisplay(List<dynamic>? array) {
    if (array == null || array.isEmpty) return 'N/A';
    return array.join(', ');
  }

  // Step 1: Select Denomination
  Widget _buildDenominationSelection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('draws').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  'No draws found in database',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final denominations = <String>{};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['denomination'] != null) {
            denominations.add(data['denomination'].toString());
          }
        }

        if (denominations.isEmpty) {
          return Center(
            child: Text(
              'No denominations found',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Select Denomination',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a bond value to view draws',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ...denominations.map((denomination) {
              return _buildDenominationCard(denomination, snapshot.data!.docs);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildDenominationCard(String denomination, List<QueryDocumentSnapshot> docs) {
    final draws = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['denomination'] == denomination;
    }).toList();

    if (draws.isEmpty) return Container();

    draws.sort((a, b) {
      final aNum = int.tryParse((a.data() as Map<String, dynamic>)['drawNumber'] ?? '0') ?? 0;
      final bNum = int.tryParse((b.data() as Map<String, dynamic>)['drawNumber'] ?? '0') ?? 0;
      return bNum.compareTo(aNum);
    });

    final latestDraw = draws.first.data() as Map<String, dynamic>;
    final latestDrawNumber = latestDraw['drawNumber']?.toString() ?? 'N/A';
    final latestDrawDate = _formatDate(latestDraw['drawDate']);
    final latestCity = latestDraw['city']?.toString() ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedDenomination = denomination;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    denomination.replaceAll('Rs.', '').replaceAll(',', '').trim(),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      denomination,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.new_releases, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Latest: $latestDrawNumber',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                latestDrawDate,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                latestCity,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${draws.length} total draws',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Step 2: Select Draw Number
  Widget _buildDrawNumberSelection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('draws')
          .where('denomination', isEqualTo: _selectedDenomination)
          .orderBy('drawNumber', descending: true)
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
                const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No draws found for $_selectedDenomination',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDenomination = null;
                    });
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedDenomination = null;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    _selectedDenomination ?? '',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select a draw number to view details',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ...snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildDrawCard(data);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildDrawCard(Map<String, dynamic> data) {
    final drawNumber = data['drawNumber']?.toString() ?? '0';
    final drawDate = _formatDate(data['drawDate']);
    final city = data['city']?.toString() ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryColor, AppColors.primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              drawNumber,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        title: Text(
          'Draw $drawNumber',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(drawDate, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_city, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _loadDrawDetails(data),
      ),
    );
  }

  // Step 3: Show Draw Details
  Widget _buildDrawDetails() {
    if (_drawDetails == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final drawDate = _formatDate(_drawDetails!['drawDate']);
    final expiryDate = _formatDate(_drawDetails!['expiryDate']);
    final city = _drawDetails!['city']?.toString() ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedDrawNumber = null;
              _drawDetails = null;
              _winningNumbers = [];
            });
          },
        ),
        title: Text(
          '${_selectedDenomination} - Draw $_selectedDrawNumber',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadDrawList,
              tooltip: 'Download',
            ),
          if (_isSharing)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareDrawList,
              tooltip: 'Share',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draw Information',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Denomination', _selectedDenomination ?? ''),
                    _buildInfoRow('Draw Number', _selectedDrawNumber ?? ''),
                    _buildInfoRow('Date', drawDate),
                    _buildInfoRow('City', city),
                    if (expiryDate != 'N/A') _buildInfoRow('Expiry Date', expiryDate),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_winningNumbers.isNotEmpty)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Winning Numbers',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildWinningNumbersList(_winningNumbers),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _buildPrizeStructure(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _isDownloading
                      ? ElevatedButton(
                    onPressed: null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Downloading...'),
                      ],
                    ),
                  )
                      : ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download as Text File'),
                    onPressed: _downloadDrawList,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isSharing
                      ? OutlinedButton(
                    onPressed: null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Sharing...'),
                      ],
                    ),
                  )
                      : OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share Draw List'),
                    onPressed: _shareDrawList,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primaryColor),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinningNumbersList(List<String> numbers) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: numbers.map((number) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
          ),
          child: Text(
            number,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryColor),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrizeStructure() {
    final firstPrize = _drawDetails!['firstPrize'];
    final secondPrize = _drawDetails!['secondPrize'];
    final thirdPrize = _drawDetails!['thirdPrize'];

    final firstPrizeNumbers = _drawDetails!['firstPrizeNumbers'] is List
        ? _formatArrayDisplay(List<dynamic>.from(_drawDetails!['firstPrizeNumbers']))
        : '';
    final secondPrizeNumbers = _drawDetails!['secondPrizeNumbers'] is List
        ? _formatArrayDisplay(List<dynamic>.from(_drawDetails!['secondPrizeNumbers']))
        : '';
    final thirdPrizeNumbers = _drawDetails!['thirdPrizeNumbers'] is List
        ? _formatArrayDisplay(List<dynamic>.from(_drawDetails!['thirdPrizeNumbers']))
        : '';

    if (firstPrize == null && secondPrize == null && thirdPrize == null) {
      return Container();
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prize Structure',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            if (firstPrize != null)
              _buildPrizeRow('First Prize', firstPrize, firstPrizeNumbers),
            if (secondPrize != null)
              _buildPrizeRow('Second Prize', secondPrize, secondPrizeNumbers),
            if (thirdPrize != null)
              _buildPrizeRow('Third Prize', thirdPrize, thirdPrizeNumbers),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeRow(String label, dynamic prizeData, String numbers) {
    String displayText = '';
    String numbersText = '';

    if (prizeData is Map<String, dynamic>) {
      final value = prizeData['value']?.toString() ?? '';
      final count = prizeData['count']?.toString() ?? '';
      displayText = 'Value: $value | Count: $count';
    } else {
      displayText = prizeData.toString();
    }

    if (numbers.isNotEmpty && numbers != 'N/A') {
      numbersText = numbers;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayText,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (numbersText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Numbers: $numbersText',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 20),
      ],
    );
  }

  void _loadDrawDetails(Map<String, dynamic> data) {
    setState(() {
      _selectedDrawNumber = data['drawNumber']?.toString();
      _drawDetails = data;
      _winningNumbers = [];

      final possibleFields = [
        'winningNumbers',
        'firstPrizeNumbers',
        'secondPrizeNumbers',
        'thirdPrizeNumbers',
        'firstPrize',
        'winningNumber'
      ];

      for (var field in possibleFields) {
        if (data[field] != null) {
          if (data[field] is List) {
            _winningNumbers.addAll(
                List<String>.from(data[field])
                    .where((num) => num.toString().trim().isNotEmpty)
                    .map((num) => num.toString())
                    .toList()
            );
          } else if (data[field] is String && data[field].toString().trim().isNotEmpty) {
            _winningNumbers.add(data[field].toString());
          }
        }
      }

      _winningNumbers = _winningNumbers.toSet().toList();
    });
  }

  Future<void> _downloadDrawList() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // For Android 13+, we need to check if we need storage permission
      bool hasPermission = false;

      if (await Permission.storage.request().isGranted) {
        hasPermission = true;
      } else if (await Permission.manageExternalStorage.request().isGranted) {
        hasPermission = true;
      }

      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please grant storage permission to download'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // Get external storage directory
      Directory? directory;

      if (Platform.isAndroid) {
        // Try to get Downloads directory
        directory = await getExternalStorageDirectory();
        if (directory == null) {
          // Fallback to app documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Cannot access storage directory');
      }

      // Create content
      String content = '''
PAKBOND DRAW LIST
================================

Denomination: $_selectedDenomination
Draw Number: $_selectedDrawNumber
Date: ${_formatDate(_drawDetails!['drawDate'])}
City: ${_drawDetails!['city'] ?? 'N/A'}
Expiry Date: ${_formatDate(_drawDetails!['expiryDate'])}

WINNING NUMBERS:
${_winningNumbers.join(', ')}

PRIZE INFORMATION:
${_buildTextPrizeInfo()}

Total Winning Numbers: ${_winningNumbers.length}

================================
Generated on: ${DateTime.now().toString()}
      ''';

      // Create file
      final fileName = 'Pakbond_Draw_${_selectedDenomination}_$_selectedDrawNumber.txt'
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_');

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      await file.writeAsString(content);

      // Try to open the file
      await OpenFile.open(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draw list saved: $fileName'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () => OpenFile.open(filePath),
          ),
        ),
      );

    } catch (e) {
      print('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _shareDrawList() async {
    setState(() {
      _isSharing = true;
    });

    try {
      // First try to download and then share
      final directory = await getTemporaryDirectory();
      final fileName = 'Pakbond_Draw_${_selectedDenomination}_$_selectedDrawNumber.txt'
          .replaceAll(' ', '_')
          .replaceAll('/', '_');

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Create content for sharing
      String content = '''
PAKBOND DRAW LIST
========================

Denomination: $_selectedDenomination
Draw Number: $_selectedDrawNumber
Date: ${_formatDate(_drawDetails!['drawDate'])}
City: ${_drawDetails!['city'] ?? 'N/A'}

WINNING NUMBERS:
${_winningNumbers.join(', ')}

Total Numbers: ${_winningNumbers.length}

PRIZE INFORMATION:
${_buildTextPrizeInfo()}

========================
Shared via Pakbond App
      ''';

      await file.writeAsString(content);

      // Share the file
      await Share.shareFiles(
        [filePath],
        text: 'Pakbond Draw List\n'
            '${_selectedDenomination} - Draw $_selectedDrawNumber\n'
            'Winning Numbers: ${_winningNumbers.join(', ')}',
        subject: 'Pakbond Draw List - ${_selectedDenomination} Draw $_selectedDrawNumber',
      );

    } catch (e) {
      print('Share error: $e');

      // Fallback: Share text only if file sharing fails
      try {
        String shareText = '''
PAKBOND DRAW LIST

${_selectedDenomination} - Draw $_selectedDrawNumber
Date: ${_formatDate(_drawDetails!['drawDate'])}
City: ${_drawDetails!['city'] ?? 'N/A'}

Winning Numbers: ${_winningNumbers.join(', ')}

Total Numbers: ${_winningNumbers.length}

Download Pakbond App for more details!
        ''';

        await Share.share(
          shareText,
          subject: 'Pakbond Draw List - ${_selectedDenomination} Draw $_selectedDrawNumber',
        );
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  String _buildTextPrizeInfo() {
    String info = '';

    final firstPrize = _drawDetails!['firstPrize'];
    final secondPrize = _drawDetails!['secondPrize'];
    final thirdPrize = _drawDetails!['thirdPrize'];

    if (firstPrize is Map<String, dynamic>) {
      info += 'First Prize: ${firstPrize['value']} (Count: ${firstPrize['count']})\n';
    }
    if (secondPrize is Map<String, dynamic>) {
      info += 'Second Prize: ${secondPrize['value']} (Count: ${secondPrize['count']})\n';
    }
    if (thirdPrize is Map<String, dynamic>) {
      info += 'Third Prize: ${thirdPrize['value']} (Count: ${thirdPrize['count']})\n';
    }

    return info.isEmpty ? 'No prize information available' : info;
  }
}
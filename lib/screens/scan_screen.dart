// lib/screens/scan_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:confetti/confetti.dart';
import 'package:app/widgets/bond_result_card.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // camera wali cheezein
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isLiveScanning = false;
  String _liveScanResult = '';
  bool _showScannerLine = true;

  // jeet pe confetti
  late ConfettiController _confettiController;
  bool _showCelebration = false;
  bool _showSadEmoji = false;

  String _scannedBondNumber = '';
  String _bondDenomination = '';
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isChecking = false;
  Map<String, dynamic>? _scanResult;
  String _errorMessage = '';
  File? _selectedImage;
  List<String> _recentScans = [];

  // denomination list draw screen jaisa
  final List<String> _denominations = [
    '100',
    '200',
    '750',
    '1500',
    '25000',
    '40000',
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 6));
    _loadRecentScans();
    _initializeCamera();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _cameraController?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _loadRecentScans() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('scanned_bonds')
          .orderBy('scannedAt', descending: true)
          .limit(5)
          .get();

      if (!mounted) return;
      setState(() {
        _recentScans = snapshot.docs
            .map((doc) => doc.data()['bondNumber'].toString())
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading recent scans: $e');
    }
  }

  Future<String?> _showDenominationDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Denomination'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _denominations.map((denom) {
            return ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: Text('Rs. $denom Prize Bond'),
              onTap: () {
                Navigator.pop(context, denom);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanFromGallery() async {
    final selectedDenomination = await _showDenominationDialog();
    if (selectedDenomination == null) return;

    setState(() {
      _bondDenomination = selectedDenomination;
      _isScanning = true;
      _errorMessage = '';
      _selectedImage = null;
      _scanResult = null;
      _showCelebration = false;
      _showSadEmoji = false;
    });

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _selectedImage = File(image.path);
        _isProcessing = true;
      });

      await _performOCR(_selectedImage!);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Gallery scan failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _startLiveCameraScan() async {
    if (!_isCameraInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedDenomination = await _showDenominationDialog();
    if (selectedDenomination == null) return;

    setState(() {
      _bondDenomination = selectedDenomination;
      _isLiveScanning = true;
      _liveScanResult = '';
      _errorMessage = '';
      _scannedBondNumber = '';
      _scanResult = null;
      _showCelebration = false;
      _showSadEmoji = false;
    });

    _startSmartScanning();
  }

  void _startSmartScanning() {
    if (!_isLiveScanning || _cameraController == null) return;

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!_isLiveScanning || _scannedBondNumber.isNotEmpty) return;

      try {
        final image = await _cameraController!.takePicture();
        await _processLiveImage(File(image.path));

        if (_scannedBondNumber.isEmpty && _isLiveScanning) {
          _startSmartScanning();
        }
      } catch (e) {
        debugPrint('Error in smart scan: $e');
        if (_isLiveScanning) {
          _startSmartScanning();
        }
      }
    });
  }

  Future<void> _processLiveImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final bondNumber = _extractBondNumberAdvanced(recognizedText.text);

      if (bondNumber.isNotEmpty && bondNumber.length == 6 && _isValidBondNumber(bondNumber)) {
        setState(() {
          _liveScanResult = '✓ Found: $bondNumber';
          _scannedBondNumber = bondNumber;
        });

        _stopLiveScanning();
        await _checkBondInDraws();
      } else if (bondNumber.isNotEmpty) {
        setState(() {
          _liveScanResult = 'Detecting: $bondNumber';
        });
      } else {
        setState(() {
          _liveScanResult = 'Scanning...';
        });
      }
    } catch (e) {
      debugPrint('Error processing live image: $e');
    }
  }

  String _extractBondNumberAdvanced(String text) {
    String cleanText = text.replaceAll(RegExp(r'[^\d\n]'), '');
    List<String> lines = cleanText.split('\n');

    for (String line in lines) {
      line = line.trim();
      if (line.length == 6 && RegExp(r'^\d{6}$').hasMatch(line)) {
        if (_isValidBondNumber(line)) {
          return line;
        }
      }

      if (line.length > 6) {
        RegExp regex = RegExp(r'\d{6}');
        Iterable<Match> matches = regex.allMatches(line);

        for (Match match in matches) {
          String possibleNumber = match.group(0)!;
          if (_isValidBondNumber(possibleNumber)) {
            return possibleNumber;
          }
        }
      }
    }

    RegExp fallbackRegex = RegExp(r'\d{6}');
    Match? match = fallbackRegex.firstMatch(text.replaceAll(RegExp(r'[^\d]'), ''));

    if (match != null) {
      return match.group(0)!;
    }

    return '';
  }

  bool _isValidBondNumber(String number) {
    if (number.length != 6) return false;

    if (RegExp(r'^(\d)\1{5}$').hasMatch(number)) return false;

    bool isSequential = true;
    bool isReverseSequential = true;

    for (int i = 0; i < 5; i++) {
      int current = int.parse(number[i]);
      int next = int.parse(number[i + 1]);

      if (next != current + 1) isSequential = false;
      if (next != current - 1) isReverseSequential = false;
    }

    if (isSequential || isReverseSequential) return false;

    return true;
  }

  void _stopLiveScanning() {
    setState(() {
      _isLiveScanning = false;
      _showScannerLine = false;
    });
  }

  Future<void> _checkBondInDraws() async {
    if (_scannedBondNumber.isEmpty || _bondDenomination.isEmpty) {
      setState(() {
        _errorMessage = 'Please scan a bond and select denomination first';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = '';
      _showCelebration = false;
      _showSadEmoji = false;
    });

    try {
      Query query = _firestore
          .collection('draws')
          .orderBy('drawDate', descending: true)
          .limit(100);

      query = query.where('denomination', isEqualTo: _bondDenomination);

      final drawsSnapshot = await query.get();

      Map<String, dynamic>? winningDraw;
      String prizeType = '';

      for (final draw in drawsSnapshot.docs) {
        final data = draw.data() as Map<String, dynamic>;

        final firstPrize = data['firstPrize']?.toString().trim();
        if (firstPrize == _scannedBondNumber) {
          winningDraw = data;
          prizeType = 'First Prize';
          break;
        }

        final secondPrizes = data['secondPrize'];
        if (secondPrizes is List) {
          for (var prize in secondPrizes) {
            if (prize.toString().trim() == _scannedBondNumber) {
              winningDraw = data;
              prizeType = 'Second Prize';
              break;
            }
          }
        }
        if (winningDraw != null) break;

        final thirdPrizeData = data['thirdPrize'];
        if (thirdPrizeData != null) {
          if (thirdPrizeData is List) {
            for (var prize in thirdPrizeData) {
              if (prize.toString().trim() == _scannedBondNumber) {
                winningDraw = data;
                prizeType = 'Third Prize';
                break;
              }
            }
          } else if (thirdPrizeData is String) {
            final numbers = thirdPrizeData.split(RegExp(r'[ ,]+'));
            for (final num in numbers) {
              if (num.trim() == _scannedBondNumber) {
                winningDraw = data;
                prizeType = 'Third Prize';
                break;
              }
            }
          }
        }
        if (winningDraw != null) break;
      }

      if (winningDraw != null) {
        setState(() {
          _scanResult = {
            'isWinner': true,
            'bondNumber': _scannedBondNumber,
            'prizeAmount': _getPrizeAmount(_bondDenomination, prizeType),
            'prizeType': prizeType,
            'drawNumber': winningDraw?['drawNumber'] ?? '',
            'drawDate': winningDraw?['drawDate'] ?? '',
            'city': winningDraw?['city'] ?? '',
            'denomination': _bondDenomination,
          };
          _showCelebration = true;
        });

        _confettiController.play();

        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() {
              _showCelebration = false;
            });
          }
        });

      } else {
        setState(() {
          _scanResult = {
            'isWinner': false,
            'bondNumber': _scannedBondNumber,
            'denomination': _bondDenomination,
            'message': 'Not found in winning bonds',
          };
          _showSadEmoji = true;
        });

        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() {
              _showSadEmoji = false;
            });
          }
        });
      }

      await _saveScanHistory();

    } catch (e) {
      debugPrint('Error checking bond: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  int _getPrizeAmount(String denomination, String prizeType) {
    final denom = int.tryParse(denomination) ?? 0;

    switch (prizeType) {
      case 'First Prize':
        return denom * 7500;
      case 'Second Prize':
        return denom * 2500;
      case 'Third Prize':
        return denom * 6;
      default:
        return 0;
    }
  }

  Future<void> _saveScanHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('scanned_bonds')
          .add({
        'bondNumber': _scannedBondNumber,
        'denomination': _bondDenomination,
        'isWinner': _scanResult?['isWinner'] ?? false,
        'scannedAt': FieldValue.serverTimestamp(),
        'checkedAt': FieldValue.serverTimestamp(),
      });

      await _loadRecentScans();
    } catch (e) {
      debugPrint('Error saving scan history: $e');
    }
  }

  Future<void> _saveToMyBonds() async {
    final user = _auth.currentUser;
    if (user == null || _scannedBondNumber.isEmpty) return;

    try {
      setState(() {
        _isChecking = true;
      });

      final existingSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_bonds')
          .where('bondNumber', isEqualTo: _scannedBondNumber)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bond #$_scannedBondNumber is already saved'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isChecking = false;
        });
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_bonds')
          .doc(_scannedBondNumber)
          .set({
        'bondNumber': _scannedBondNumber,
        'denomination': _bondDenomination,
        'savedAt': FieldValue.serverTimestamp(),
        'isWinner': _scanResult?['isWinner'] ?? false,
        'prizeAmount': _scanResult?['prizeAmount'] ?? 0,
        'prizeType': _scanResult?['prizeType'] ?? '',
        'drawNumber': _scanResult?['drawNumber'] ?? '',
        'drawDate': _scanResult?['drawDate'] ?? '',
        'city': _scanResult?['city'] ?? '',
        'addedManually': false,
        'status': 'active',
        'lastChecked': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'bondsCount': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bond #$_scannedBondNumber saved to My Bonds'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving bond: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _shareResult() async {
    try {
      String message = 'Pakbond - Prize Bond Check Result\n\n';
      message += 'Bond Number: $_scannedBondNumber\n';
      message += 'Denomination: Rs. $_bondDenomination Prize Bond\n';

      if (_scanResult?['isWinner'] == true) {
        message += 'STATUS: WINNER!\n';
        message += 'Prize Amount: Rs. ${_scanResult?['prizeAmount']}\n';
        message += 'Prize Type: ${_scanResult?['prizeType']}\n';
        if (_scanResult?['drawNumber'] != null) {
          message += 'Draw Number: ${_scanResult?['drawNumber']}\n';
        }
        if (_scanResult?['city'] != null) {
          message += 'City: ${_scanResult?['city']}\n';
        }
      } else {
        message += '📝 STATUS: Not a winning bond\n';
        message += 'Better luck next time!\n';
      }

      message += '\nChecked via Pakbond App';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share Result'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Result copied to clipboard'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Copy'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  Widget _buildScannerLine() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 2000),
      height: 2,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.green.withValues(alpha:0.8),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha:0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  // Custom confetti path
  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prize Bond'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // live camera view
                if (_isLiveScanning && _isCameraInitialized)
                  _buildLiveCameraView(),

                // Header Card
                if (!_isLiveScanning)
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            size: 60,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Scan Prize Bond',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select denomination and scan your prize bond',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Scan Options
                if (!_isLiveScanning)
                  Column(
                    children: [
                      // live camera button
                      if (_isCameraInitialized)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startLiveCameraScan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.camera, color: Colors.white),
                            label: const Text(
                              'Live Camera Scan',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),

                      if (_isCameraInitialized) const SizedBox(height: 12),

                      // Gallery Scan
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _scanFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: _isScanning
                              ? const CircularProgressIndicator()
                              : const Text('Select from Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Selected Image Preview
                if (_selectedImage != null && !_isLiveScanning)
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Selected Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),

                // live scan status text
                if (_isLiveScanning && _liveScanResult.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _scannedBondNumber.isNotEmpty
                              ? Icons.check_circle
                              : Icons.search,
                          color: _scannedBondNumber.isNotEmpty
                              ? Colors.green
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _liveScanResult,
                            style: TextStyle(
                              color: _scannedBondNumber.isNotEmpty
                                  ? Colors.green
                                  : Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Stop Live Scan Button
                if (_isLiveScanning)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _stopLiveScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.stop, color: Colors.white),
                        label: const Text(
                          'Stop Scanning',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                // Selected Denomination
                if (_bondDenomination.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.money, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: Rs. $_bondDenomination Prize Bond',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Scanned Bond Details
                if (_scannedBondNumber.isNotEmpty && !_isLiveScanning)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Scanned Bond',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.confirmation_number),
                                title: const Text('Bond Number'),
                                subtitle: Text(
                                  _scannedBondNumber,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.money),
                                title: const Text('Denomination'),
                                subtitle: Text(
                                  'Rs. $_bondDenomination',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                if (_scannedBondNumber.isNotEmpty &&
                    _bondDenomination.isNotEmpty &&
                    _scanResult == null &&
                    !_isChecking)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _checkBondInDraws,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.search, color: Colors.white),
                        label: const Text(
                          'Check in Draw Results',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                if (_isChecking)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Checking bond in database...'),
                        ],
                      ),
                    ),
                  ),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Scan Result
                if (_scanResult != null)
                  BondResultCard(
                    bondNumber: _scannedBondNumber,
                    denomination: 'Rs. ${_scanResult!['denomination'] ?? _bondDenomination} Prize Bond',
                    isWinner: _scanResult!['isWinner'] == true,
                    prizeAmount: _scanResult!['prizeAmount'] ?? 0,
                    prizeType: _scanResult!['prizeType']?.toString() ?? '',
                    drawNumber: _scanResult!['drawNumber']?.toString() ?? '',
                    drawDate: _scanResult!['drawDate'] != null
                        ? ((_scanResult!['drawDate'] is Timestamp)
                        ? (_scanResult!['drawDate'] as Timestamp).toDate()
                        : DateTime.parse(_scanResult!['drawDate'].toString()))
                        : null,
                    city: _scanResult!['city']?.toString() ?? '',
                    onSave: _saveToMyBonds,
                    onShare: _shareResult,
                    onCheckAgain: _checkBondInDraws,
                  ),

                // Recent Scans
                if (_recentScans.isNotEmpty && !_isLiveScanning)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Scans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: _recentScans.map((scan) => ListTile(
                              leading: const Icon(Icons.history),
                              title: Text('Bond: $scan'),
                              trailing: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () {
                                  setState(() {
                                    _scannedBondNumber = scan;
                                    _scanResult = null;
                                  });
                                  _showDenominationDialog().then((denom) {
                                    if (denom != null) {
                                      setState(() {
                                        _bondDenomination = denom;
                                      });
                                      _checkBondInDraws();
                                    }
                                  });
                                },
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Confetti Celebration
          if (_showCelebration)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                maxBlastForce: 30,
                minBlastForce: 20,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.1,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                  Colors.red,
                  Colors.teal,
                  Colors.indigo,
                  Colors.amber,
                ],
                createParticlePath: _drawStar,
              ),
            ),

          // Sad Emoji for non-winner
          if (_showSadEmoji)
            Positioned(
              right: 20,
              top: MediaQuery.of(context).padding.top + 70,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 1),
                opacity: _showSadEmoji ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha:0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '😔',
                        style: TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Better luck\nnext time!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep checking!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CameraPreview(_cameraController!),
          ),
        ),

        if (_showScannerLine)
          Positioned(
            top: 100,
            child: _buildScannerLine(),
          ),

        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green.withValues(alpha:0.5), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        Positioned(
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Point camera at bond number',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // chhoti helper functions
  Future<void> _performOCR(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final bondNumber = _extractBondNumberAdvanced(recognizedText.text);

      setState(() {
        _scannedBondNumber = bondNumber;
        _isProcessing = false;
      });

      if (bondNumber.isNotEmpty) {
        await _checkBondInDraws();
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'OCR failed: $e';
      });
    }
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app/utils/constants.dart';
import 'package:app/utils/draw_text_parser.dart';
import 'package:google_fonts/google_fonts.dart';

class UploadDrawScreen extends StatefulWidget {
  const UploadDrawScreen({super.key});

  @override
  State<UploadDrawScreen> createState() => _UploadDrawScreenState();
}

class _UploadDrawScreenState extends State<UploadDrawScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _cityController = TextEditingController(text: 'Karachi');
  ParsedDraw? _parsed;
  String? _parseError;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _textController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String text = '';
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        text = utf8.decode(file.bytes!);
      }
      if (text.isNotEmpty) {
        _textController.text = text;
        _parse();
      } else {
        setState(() => _parseError = 'File empty. Paste draw text below or pick another file.');
      }
    } catch (e) {
      setState(() => _parseError = 'Error: $e');
    }
  }

  void _parse() {
    setState(() {
      _parseError = null;
      _parsed = DrawTextParser.parse(_textController.text);
      if (_parsed == null && _textController.text.trim().isNotEmpty) {
        _parseError = 'Could not parse. Check format: RS. XXX, First Prize, Second Prize, Third Prize with 6-digit numbers.';
      }
    });
  }

  Future<void> _saveToFirestore() async {
    if (_parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parse the text first'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final drawRef = await _firestore.collection('draws').add({
        'drawNumber': _parsed!.drawNumber,
        'denomination': _parsed!.denomination,
        'drawDate': FieldValue.serverTimestamp(),
        'city': _cityController.text.trim().isEmpty ? 'Karachi' : _cityController.text.trim(),
        'firstPrize': _parsed!.firstPrize,
        'secondPrize': _parsed!.secondPrize,
        'thirdPrize': _parsed!.thirdPrize,
        'totalPrizes': 1 + _parsed!.secondPrize.length + _parsed!.thirdPrize.length,
        'addedAt': FieldValue.serverTimestamp(),
      });

      final String denom = _parsed!.denomination;
      final String drawNum = _parsed!.drawNumber;
      final String msg = 'Rs. $denom draw #$drawNum has been uploaded.';
      await _firestore.collection('draw_announcements').add({
        'drawId': drawRef.id,
        'denomination': denom,
        'drawNumber': drawNum,
        'message': msg,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _notifyWinners(denom, drawNum);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draw saved to database'), backgroundColor: Colors.green),
        );
        _textController.clear();
        _cityController.text = 'Karachi';
        setState(() {
          _parsed = null;
          _parseError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _notifyWinners(String denomination, String drawNumber) async {
    final String first = _parsed!.firstPrize.trim();
    final List<String> second = _parsed!.secondPrize.map((e) => e.trim()).toList();
    final List<String> third = _parsed!.thirdPrize.map((e) => e.trim()).toList();

    final usersSnap = await _firestore.collection('users').get();
    for (final userDoc in usersSnap.docs) {
      final uid = userDoc.id;
      final bondsSnap = await _firestore.collection('users').doc(uid).collection('my_bonds').get();
      for (final bondDoc in bondsSnap.docs) {
        final bondNumber = bondDoc.data()['bondNumber']?.toString().trim();
        if (bondNumber == null || bondNumber.isEmpty) continue;
        String? prizeType;
        if (first == bondNumber) {
          prizeType = 'FIRST';
        } else if (second.contains(bondNumber)) {
          prizeType = 'SECOND';
        } else if (third.contains(bondNumber)) {
          prizeType = 'THIRD';
        }
        if (prizeType == null) continue;
        final String body =
            'Your bond $bondNumber matched this draw (${prizeType == 'FIRST' ? 'First' : prizeType == 'SECOND' ? 'Second' : 'Third'} prize).';
        await _firestore.collection('winner_notifications').doc(uid).collection('alerts').add({
          'bondNumber': bondNumber,
          'drawNumber': drawNumber,
          'denomination': denomination,
          'prizeType': prizeType,
          'message': body,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: const Text('Add Draw (Upload TXT)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select a .txt file or paste the official draw result below. Denomination, draw number, and prize numbers are parsed automatically.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Denomination is read from the text (e.g. Rs. 100, 200, 750, 1500, 25000, 40000).',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose TXT file'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _parse,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                          icon: const Icon(Icons.pause),
                          label: const Text('Parse'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    maxLines: 14,
                    decoration: InputDecoration(
                      hintText: 'Paste draw result (e.g. DRAW RESULT OF RS. 750/- … 105TH DRAW … First Prize … 809258 …)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  if (_parseError != null) ...[
                    const SizedBox(height: 8),
                    Text(_parseError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  if (_parsed != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Parsed: Rs. ${_parsed!.denomination} - Draw #${_parsed!.drawNumber}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('First Prize: ${_parsed!.firstPrize}'),
                            Text('Second Prizes: ${_parsed!.secondPrize.length}'),
                            Text('Third Prizes: ${_parsed!.thirdPrize.length}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveToFirestore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save to Database'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDrawsListScreen extends StatefulWidget {
  const AdminDrawsListScreen({super.key});

  @override
  State<AdminDrawsListScreen> createState() => _AdminDrawsListScreenState();
}

class _AdminDrawsListScreenState extends State<AdminDrawsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _draws = [];

  @override
  void initState() {
    super.initState();
    _loadDraws();
  }

  Future<void> _loadDraws() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore
          .collection('draws')
          .orderBy('addedAt', descending: true)
          .get();
      setState(() {
        _draws = snapshot.docs
            .map((d) => d as QueryDocumentSnapshot<Map<String, dynamic>>)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading draws: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDraw(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draw'),
        content: Text(
          'Delete Rs. ${doc.data()['denomination']} Draw #${doc.data()['drawNumber']}? This will remove it from Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draw deleted from Firestore'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadDraws();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: const Text('Uploaded Draws'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDraws,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _draws.isEmpty
              ? Center(
                  child: Text(
                    'No draws uploaded yet',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDraws,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _draws.length,
                    itemBuilder: (context, index) {
                      final doc = _draws[index];
                      final d = doc.data();
                      final denom = d['denomination']?.toString() ?? '';
                      final drawNum = d['drawNumber']?.toString() ?? '';
                      final city = d['city']?.toString() ?? '';
                      final addedAt = d['addedAt'];
                      String addedStr = '';
                      if (addedAt != null && addedAt is Timestamp) {
                        addedStr = '${addedAt.toDate().day}/${addedAt.toDate().month}/${addedAt.toDate().year}';
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            'Rs. $denom Draw #$drawNum',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '$city${addedStr.isNotEmpty ? ' · $addedStr' : ''}',
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteDraw(doc),
                            tooltip: 'Delete from Firestore',
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

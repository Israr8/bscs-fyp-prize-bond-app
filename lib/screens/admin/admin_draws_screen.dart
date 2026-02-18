// lib/screens/admin_draws_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/utils/constants.dart';
import 'package:intl/intl.dart';

class AdminDrawsScreen extends StatefulWidget {
  const AdminDrawsScreen({super.key});

  @override
  State<AdminDrawsScreen> createState() => _AdminDrawsScreenState();
}

class _AdminDrawsScreenState extends State<AdminDrawsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _recentDraws = [];
  bool _isLoading = false;

  // Sample prize bond results structure
  final Map<String, Map<String, dynamic>> _sampleDraws = {
    '200': {
      'drawNumber': '101',
      'drawDate': '2024-03-15',
      'denomination': '200',
      'city': 'Karachi',
      'totalPrizes': 1000,
      'firstPrize': '123456',
      'secondPrize': ['234567', '234568', '234569'],
      'thirdPrize': List.generate(100, (i) => (345678 + i).toString()),
      'source': 'State Bank of Pakistan',
    },
    '750': {
      'drawNumber': '102',
      'drawDate': '2024-03-15',
      'denomination': '750',
      'city': 'Lahore',
      'totalPrizes': 500,
      'firstPrize': '654321',
      'secondPrize': ['765432', '765433', '765434'],
      'thirdPrize': List.generate(50, (i) => (876543 + i).toString()),
      'source': 'National Savings',
    },
    '1500': {
      'drawNumber': '103',
      'drawDate': '2024-03-15',
      'denomination': '1500',
      'city': 'Islamabad',
      'totalPrizes': 300,
      'firstPrize': '987654',
      'secondPrize': ['876543', '876544', '876545'],
      'thirdPrize': List.generate(30, (i) => (765432 + i).toString()),
      'source': 'Dawn Newspaper',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadRecentDraws();
  }

  Future<void> _loadRecentDraws() async {
    try {
      final snapshot = await _firestore
          .collection('draws')
          .orderBy('drawDate', descending: true)
          .limit(5)
          .get();

      setState(() {
        _recentDraws.clear();
        for (var doc in snapshot.docs) {
          _recentDraws.add({'id': doc.id, ...doc.data()});
        }
      });
    } catch (e) {
      debugPrint('Error loading draws: $e');
    }
  }

  Future<void> _addSampleDraws() async {
    setState(() => _isLoading = true);

    try {
      for (var draw in _sampleDraws.values) {
        await _firestore.collection('draws').add({
          ...draw,
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': 'Admin',
          'status': 'active',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sample draw results added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRecentDraws();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewDraw() async {
    final formKey = GlobalKey<FormState>();
    final TextEditingController drawNumberController = TextEditingController();
    final TextEditingController denominationController = TextEditingController(text: '200');
    final TextEditingController cityController = TextEditingController(text: 'Karachi');
    final TextEditingController firstPrizeController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Draw Result'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: drawNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Draw Number',
                        hintText: 'e.g., 101',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter draw number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: denominationController.text,
                      decoration: const InputDecoration(labelText: 'Denomination'),
                      items: const [
                        DropdownMenuItem(value: '200', child: Text('Rs. 200')),
                        DropdownMenuItem(value: '750', child: Text('Rs. 750')),
                        DropdownMenuItem(value: '1500', child: Text('Rs. 1,500')),
                        DropdownMenuItem(value: '7500', child: Text('Rs. 7,500')),
                        DropdownMenuItem(value: '15000', child: Text('Rs. 15,000')),
                        DropdownMenuItem(value: '25000', child: Text('Rs. 25,000')),
                        DropdownMenuItem(value: '40000', child: Text('Rs. 40,000')),
                      ],
                      onChanged: (value) {
                        denominationController.text = value!;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: firstPrizeController,
                      decoration: const InputDecoration(
                        labelText: 'First Prize Bond Number',
                        hintText: 'e.g., 123456',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _saveNewDraw(
                      drawNumberController.text,
                      denominationController.text,
                      cityController.text,
                      selectedDate,
                      firstPrizeController.text,
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveNewDraw(
      String drawNumber,
      String denomination,
      String city,
      DateTime drawDate,
      String firstPrize,
      ) async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('draws').add({
        'drawNumber': drawNumber,
        'denomination': denomination,
        'city': city,
        'drawDate': Timestamp.fromDate(drawDate),
        'firstPrize': firstPrize,
        'secondPrize': _generateSampleNumbers(3, 200000), // Sample data
        'thirdPrize': _generateSampleNumbers(10, 300000), // Sample data
        'totalPrizes': 1000,
        'source': 'Manual Entry',
        'addedBy': 'Admin',
        'addedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ New draw result added!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRecentDraws();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _generateSampleNumbers(int count, int start) {
    return List.generate(count, (i) => (start + i).toString());
  }

  Future<void> _deleteDraw(String drawId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draw'),
        content: const Text('Are you sure you want to delete this draw?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection('draws').doc(drawId).delete();
      await _loadRecentDraws();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw deleted'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Draw Results'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewDraw,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Draw Results Database',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total Draws', _recentDraws.length.toString()),
                        _buildStatItem('Last Added', _recentDraws.isNotEmpty
                            ? DateFormat('dd/MM').format(
                            (_recentDraws.first['drawDate'] as Timestamp).toDate())
                            : 'None'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addSampleDraws,
                    icon: const Icon(Icons.download),
                    label: const Text('Load Sample Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadRecentDraws,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Draws List
            Expanded(
              child: _recentDraws.isEmpty
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
                      'No draw results found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add sample data or create new draws',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addSampleDraws,
                      child: const Text('Load Sample Data'),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _recentDraws.length,
                itemBuilder: (context, index) {
                  final draw = _recentDraws[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                        child: Text(
                          draw['drawNumber'].toString().substring(0, 1),
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        'Draw #${draw['drawNumber']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rs. ${draw['denomination']} Prize Bond'),
                          Text(
                            DateFormat('dd MMM yyyy').format(
                              (draw['drawDate'] as Timestamp).toDate(),
                            ),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDraw(draw['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
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
}
// lib/utils/sample_data_loader.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SampleDataLoader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addSamplePrizeBonds() async {
    try {
      // Sample winning bonds for Rs. 200 denomination
      final bonds200 = [
        {
          'bondNumber': '123456',
          'denomination': '200',
          'prizeAmount': 1500000,
          'prizeType': 'First Prize',
          'drawNumber': '101',
          'drawDate': Timestamp.fromDate(DateTime(2024, 3, 15)),
          'series': '2023',
          'addedAt': FieldValue.serverTimestamp(),
        },
        {
          'bondNumber': '234567',
          'denomination': '200',
          'prizeAmount': 500000,
          'prizeType': 'Second Prize',
          'drawNumber': '101',
          'drawDate': Timestamp.fromDate(DateTime(2024, 3, 15)),
          'series': '2023',
          'addedAt': FieldValue.serverTimestamp(),
        },
        {
          'bondNumber': '345678',
          'denomination': '200',
          'prizeAmount': 100000,
          'prizeType': 'Third Prize',
          'drawNumber': '101',
          'drawDate': Timestamp.fromDate(DateTime(2024, 3, 15)),
          'series': '2023',
          'addedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (var bond in bonds200) {
        await _firestore.collection('prize_bonds').add(bond);
      }

      debugPrint('✅ Sample prize bond data added successfully!');
    } catch (e) {
      debugPrint('❌ Error adding sample data: $e');
    }
  }

  Future<Map<String, dynamic>> getPrizeBondStats() async {
    try {
      final snapshot = await _firestore.collection('prize_bonds').get();
      final totalBonds = snapshot.docs.length;

      final bondsByDenomination = {
        '200': snapshot.docs.where((doc) => doc['denomination'] == '200').length,
        '750': snapshot.docs.where((doc) => doc['denomination'] == '750').length,
        '1500': snapshot.docs.where((doc) => doc['denomination'] == '1500').length,
      };

      return {
        'totalWinningBonds': totalBonds,
        'bondsByDenomination': bondsByDenomination,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {};
    }
  }
}
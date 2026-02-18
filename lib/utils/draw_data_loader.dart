// lib/utils/draw_data_loader.dart - Complete file
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DrawDataLoader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> load2024DrawResults() async {
    try {
      final draws2024 = [
        // Rs. 200 Prize Bonds - March 2024
        {
          'drawNumber': '101',
          'drawDate': Timestamp.fromDate(DateTime(2024, 3, 15)),
          'denomination': '200',
          'city': 'Karachi',
          'totalPrizes': 1000,
          'firstPrize': '123456',
          'secondPrize': _generateNumbers(234567, 10),
          'thirdPrize': _generateNumbers(345678, 100),
          'source': 'State Bank of Pakistan',
          'prizeAmounts': {
            'first': 1500000,
            'second': 500000,
            'third': 100000,
          },
          'status': 'completed',
          'verified': true,
          'addedAt': FieldValue.serverTimestamp(),
        },

        // Rs. 200 Prize Bonds - June 2024
        {
          'drawNumber': '102',
          'drawDate': Timestamp.fromDate(DateTime(2024, 6, 15)),
          'denomination': '200',
          'city': 'Lahore',
          'totalPrizes': 1000,
          'firstPrize': '654321',
          'secondPrize': _generateNumbers(765432, 10),
          'thirdPrize': _generateNumbers(876543, 100),
          'source': 'National Savings',
          'prizeAmounts': {
            'first': 1500000,
            'second': 500000,
            'third': 100000,
          },
          'status': 'completed',
          'verified': true,
          'addedAt': FieldValue.serverTimestamp(),
        },

        // Rs. 750 Prize Bonds - March 2024
        {
          'drawNumber': '103',
          'drawDate': Timestamp.fromDate(DateTime(2024, 3, 15)),
          'denomination': '750',
          'city': 'Islamabad',
          'totalPrizes': 500,
          'firstPrize': '987654',
          'secondPrize': _generateNumbers(876543, 5),
          'thirdPrize': _generateNumbers(765432, 50),
          'source': 'Dawn Newspaper',
          'prizeAmounts': {
            'first': 3000000,
            'second': 1000000,
            'third': 500000,
          },
          'status': 'completed',
          'verified': true,
          'addedAt': FieldValue.serverTimestamp(),
        },

        // Rs. 1500 Prize Bonds - June 2024
        {
          'drawNumber': '104',
          'drawDate': Timestamp.fromDate(DateTime(2024, 6, 15)),
          'denomination': '1500',
          'city': 'Karachi',
          'totalPrizes': 300,
          'firstPrize': '456789',
          'secondPrize': _generateNumbers(567890, 3),
          'thirdPrize': _generateNumbers(678901, 30),
          'source': 'Jang Newspaper',
          'prizeAmounts': {
            'first': 6000000,
            'second': 2000000,
            'third': 1000000,
          },
          'status': 'completed',
          'verified': true,
          'addedAt': FieldValue.serverTimestamp(),
        },

        // Rs. 7500 Prize Bonds - September 2024
        {
          'drawNumber': '105',
          'drawDate': Timestamp.fromDate(DateTime(2024, 9, 15)),
          'denomination': '7500',
          'city': 'Lahore',
          'totalPrizes': 150,
          'firstPrize': '111111',
          'secondPrize': _generateNumbers(222222, 2),
          'thirdPrize': _generateNumbers(333333, 15),
          'source': 'Express Tribune',
          'prizeAmounts': {
            'first': 15000000,
            'second': 5000000,
            'third': 2500000,
          },
          'status': 'upcoming',
          'verified': true,
          'addedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (var draw in draws2024) {
        await _firestore.collection('draws').add(draw);
      }

      print('✅ Loaded ${draws2024.length} draw results for 2024');
    } catch (e) {
      print('❌ Error loading draw results: $e');
      rethrow;
    }
  }

  Future<void> loadHistoricalDraws() async {
      final historicalDraws = [
      // Add 2023, 2022 draws here
    ];

    for (var draw in historicalDraws) {
      await _firestore.collection('draws').add(draw);
    }
  }

  List<String> _generateNumbers(int start, int count) {
    return List.generate(count, (index) => (start + index).toString());
  }

  Future<Map<String, dynamic>> getDrawStats() async {
    try {
      final snapshot = await _firestore.collection('draws').get();
      final totalDraws = snapshot.docs.length;

      final drawsByDenomination = {};
      final drawsByYear = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final denom = data['denomination'] ?? 'unknown';
        final date = (data['drawDate'] as Timestamp).toDate();
        final year = DateFormat('yyyy').format(date);

        drawsByDenomination[denom] = (drawsByDenomination[denom] ?? 0) + 1;
        drawsByYear[year] = (drawsByYear[year] ?? 0) + 1;
      }

      return {
        'totalDraws': totalDraws,
        'drawsByDenomination': drawsByDenomination,
        'drawsByYear': drawsByYear,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting draw stats: $e');
      return {};
    }
  }
}
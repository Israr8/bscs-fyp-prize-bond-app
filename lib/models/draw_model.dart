import 'package:cloud_firestore/cloud_firestore.dart';

class DrawResult {
  final String id;
  final String drawNumber;
  final String denomination;
  final DateTime drawDate;
  final String city;
  final int totalPrizes;
  final String firstPrize;
  final String secondPrize;
  final String thirdPrize;

  DrawResult({
    required this.id,
    required this.drawNumber,
    required this.denomination,
    required this.drawDate,
    required this.city,
    required this.totalPrizes,
    required this.firstPrize,
    required this.secondPrize,
  // Factory constructor for Firebase
    required this.thirdPrize,
  });
    // Helper function to handle prize data

  factory DrawResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String formatPrize(dynamic prize) {
      if (prize == null) return '';
      if (prize is List) {
        return prize.join(', ');
      }
    // Handle date conversion safely
      return prize.toString();
    }

    DateTime parseDate(dynamic dateData) {
      try {
        if (dateData is Timestamp) {
          return dateData.toDate();
        } else if (dateData is String) {
          return DateTime.parse(dateData);
        } else {
          return DateTime.now();
        }
      } catch (e) {
        return DateTime.now();
      }
    }

    return DrawResult(
      id: doc.id,
      drawNumber: data['drawNumber']?.toString() ?? 'N/A',
      denomination: 'Rs. ${data['denomination']?.toString() ?? '200'}',
      drawDate: parseDate(data['drawDate']),
      city: data['city']?.toString() ?? 'Karachi',
      totalPrizes: (data['totalPrizes'] as num?)?.toInt() ?? 0,
      firstPrize: formatPrize(data['firstPrize']),
      secondPrize: formatPrize(data['secondPrize']),
      thirdPrize: formatPrize(data['thirdPrize']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drawNumber': drawNumber,
      'denomination': denomination,
      'drawDate': Timestamp.fromDate(drawDate),
      'city': city,
      'totalPrizes': totalPrizes,
      'firstPrize': firstPrize,
      'secondPrize': secondPrize,
      'thirdPrize': thirdPrize,
    };
  }
}
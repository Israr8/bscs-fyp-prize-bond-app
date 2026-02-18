import 'package:cloud_firestore/cloud_firestore.dart';

class MarketItem {
  final String id;
  final String bondNumber;
  final String denomination;
  final double askingPrice;
  final String sellerName;
  final String sellerId;
  final double sellerRating;
  final DateTime postedDate;
  final String location;
  final String description;
  final bool isSold;

  MarketItem({
    required this.id,
    required this.bondNumber,
    required this.denomination,
    required this.askingPrice,
    required this.sellerName,
    required this.sellerId,
    required this.sellerRating,
    required this.postedDate,
    required this.location,
    required this.description,
    this.isSold = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'bondNumber': bondNumber,
      'denomination': denomination,
      'askingPrice': askingPrice,
      'sellerName': sellerName,
      'sellerId': sellerId,
      'sellerRating': sellerRating,
      'postedDate': postedDate.toIso8601String(),
      'location': location,
      'description': description,
      'isSold': isSold,
    };
  }

  factory MarketItem.fromMap(String id, Map<String, dynamic> map) {
    return MarketItem(
      id: id,
      bondNumber: map['bondNumber']?.toString() ?? '',
      denomination: map['denomination']?.toString() ?? '',
      askingPrice: (map['askingPrice'] as num?)?.toDouble() ?? 0.0,
      sellerName: map['sellerName']?.toString() ?? 'Anonymous',
      sellerId: map['sellerId']?.toString() ?? '',
      sellerRating: (map['sellerRating'] as num?)?.toDouble() ?? 5.0,
      postedDate: _parseDateTime(map['postedDate']),
      location: map['location']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      isSold: map['isSold'] as bool? ?? false,
    );
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    try {
      if (dateValue == null) return DateTime.now();

      if (dateValue is Timestamp) {
        return dateValue.toDate();
      }

      if (dateValue is Map && dateValue.containsKey('_seconds')) {
        final seconds = dateValue['_seconds'] as int;
        final nanoseconds = dateValue['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + (nanoseconds ~/ 1000000));
      }

      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }

      if (dateValue is DateTime) {
        return dateValue;
      }

      return DateTime.now();
    } catch (e) {
      print('Error parsing date: $e, value: $dateValue');
      return DateTime.now();
    }
  }
}
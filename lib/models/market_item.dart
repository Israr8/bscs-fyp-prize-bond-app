import 'package:cloud_firestore/cloud_firestore.dart';

class MarketItem {
  final String id;
  final String bondNumber;
  final String denomination;
  final double askingPrice;
  final String sellerName;
  final String sellerId;
  // Phone: visible to seller; buyer sees it after tapping Buy now or after sale completes.
  final String sellerPhone;
  final double sellerRating;
  final DateTime postedDate;
  final String location;
  final String description;
  final bool isSold;
  final String? buyerId;
  final String? buyerName;
  // Filled when a buyer taps Buy now; cleared when the listing is sold.
  final String? pendingBuyerId;
  final String? pendingBuyerName;
  final DateTime? contactSharedAt;

  MarketItem({
    required this.id,
    required this.bondNumber,
    required this.denomination,
    required this.askingPrice,
    required this.sellerName,
    required this.sellerId,
    this.sellerPhone = '',
    required this.sellerRating,
    required this.postedDate,
    required this.location,
    required this.description,
    this.isSold = false,
    this.buyerId,
    this.buyerName,
    this.pendingBuyerId,
    this.pendingBuyerName,
    this.contactSharedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'bondNumber': bondNumber,
      'denomination': denomination,
      'askingPrice': askingPrice,
      'sellerName': sellerName,
      'sellerId': sellerId,
      'sellerPhone': sellerPhone,
      'sellerRating': sellerRating,
      'postedDate': postedDate.toIso8601String(),
      'location': location,
      'description': description,
      'isSold': isSold,
      if (buyerId != null) 'buyerId': buyerId,
      if (buyerName != null) 'buyerName': buyerName,
      if (pendingBuyerId != null) 'pendingBuyerId': pendingBuyerId,
      if (pendingBuyerName != null) 'pendingBuyerName': pendingBuyerName,
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
      sellerPhone: map['sellerPhone']?.toString() ?? '',
      sellerRating: (map['sellerRating'] as num?)?.toDouble() ?? 5.0,
      postedDate: _parseDateTime(map['postedDate']),
      location: map['location']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      isSold: map['isSold'] as bool? ?? false,
      buyerId: map['buyerId']?.toString(),
      buyerName: map['buyerName']?.toString(),
      pendingBuyerId: map['pendingBuyerId']?.toString(),
      pendingBuyerName: map['pendingBuyerName']?.toString(),
      contactSharedAt: _parseOptionalDate(map['contactSharedAt']),
    );
  }

  static DateTime? _parseOptionalDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is Map && dateValue.containsKey('_seconds')) {
        final seconds = dateValue['_seconds'] as int;
        final nanoseconds = dateValue['_nanoseconds'] as int? ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000));
      }
      if (dateValue is String) return DateTime.parse(dateValue);
      if (dateValue is DateTime) return dateValue;
    } catch (_) {}
    return null;
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
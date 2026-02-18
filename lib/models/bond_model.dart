import 'package:cloud_firestore/cloud_firestore.dart';

class Bond {
  final String id;
  final String number;
  final String denomination;
  final DateTime purchaseDate;
  final String status;
  final bool isWon;
  final double prizeAmount;

  Bond({
    required this.id,
    required this.number,
    required this.denomination,
    required this.purchaseDate,
    required this.status,
    required this.isWon,
    required this.prizeAmount,
  });

  factory Bond.fromMap(Map<String, dynamic> map) {
    return Bond(
      id: map['id'] ?? '',
      number: map['number'] ?? '',
      denomination: map['denomination'] ?? '',
      purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'Active',
      isWon: map['isWon'] ?? false,
      prizeAmount: (map['prizeAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'denomination': denomination,
      'purchaseDate': purchaseDate,
      'status': status,
      'isWon': isWon,
      'prizeAmount': prizeAmount,
    };
  }
}
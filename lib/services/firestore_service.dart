import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/models/bond_model.dart';
import 'package:app/models/draw_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bonds Collection
  CollectionReference get bondsCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(userId).collection('bonds');
  }

  // Draws Collection
  CollectionReference get drawsCollection => _firestore.collection('draws');

  // Marketplace Collection
  CollectionReference get marketplaceCollection => _firestore.collection('marketplace');

  // Public method to check if bond is a winner (for demo)
  bool isMockWinner(String bondNumber) {
    // For demo, let's say any bond ending with '777' is a winner
    return bondNumber.endsWith('777');
  }

  // Add bond to Firestore
  Future<void> addBondToFirestore(Bond bond) async {
    try {
      await bondsCollection.doc(bond.id).set({
        'id': bond.id,
        'number': bond.number,
        'denomination': bond.denomination,
        'purchaseDate': bond.purchaseDate,
        'status': bond.status,
        'isWon': bond.isWon,
        'prizeAmount': bond.prizeAmount,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add bond: $e');
    }
  }

  // Get bonds from Firestore
  Future<List<Bond>> getBondsFromFirestore() async {
    try {
      final querySnapshot = await bondsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Bond(
          id: data['id'] ?? doc.id,
          number: data['number'] ?? '',
          denomination: data['denomination'] ?? 'Rs. 200',
          purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'Active',
          isWon: data['isWon'] ?? false,
          prizeAmount: (data['prizeAmount'] ?? 0).toDouble(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get bonds: $e');
    }
  }

  // Stream bonds from Firestore (real-time updates)
  Stream<List<Bond>> getBondsStream() {
    return bondsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Bond(
          id: data['id'] ?? doc.id,
          number: data['number'] ?? '',
          denomination: data['denomination'] ?? 'Rs. 200',
          purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? 'Active',
          isWon: data['isWon'] ?? false,
          prizeAmount: (data['prizeAmount'] ?? 0).toDouble(),
        );
      }).toList();
    });
  }

  // Delete bond from Firestore
  Future<void> deleteBondFromFirestore(String bondId) async {
    try {
      await bondsCollection.doc(bondId).delete();
    } catch (e) {
      throw Exception('Failed to delete bond: $e');
    }
  }

  // Update bond in Firestore
  Future<void> updateBondInFirestore(Bond bond) async {
    try {
      await bondsCollection.doc(bond.id).update({
        'number': bond.number,
        'denomination': bond.denomination,
        'purchaseDate': bond.purchaseDate,
        'status': bond.status,
        'isWon': bond.isWon,
        'prizeAmount': bond.prizeAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update bond: $e');
    }
  }

  // Get draw results
  Future<List<DrawResult>> getDrawResults() async {
    try {
      final querySnapshot = await drawsCollection
          .orderBy('drawDate', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DrawResult(
          id: doc.id,
          drawNumber: data['drawNumber'] ?? '',
          denomination: data['denomination'] ?? 'Rs. 200',
          drawDate: (data['drawDate'] as Timestamp).toDate(),
          city: data['city'] ?? 'Karachi',
          totalPrizes: data['totalPrizes'] ?? 0,
          firstPrize: data['firstPrize'] ?? '',
          secondPrize: data['secondPrize'] ?? '',
          thirdPrize: data['thirdPrize'] ?? '',
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get draw results: $e');
    }
  }

  // Check bond number
  Future<Map<String, dynamic>> checkBondNumber(String bondNumber, String denomination) async {
    try {
      // Use the public method
      final isWinner = isMockWinner(bondNumber);

      if (isWinner) {
        return {
          'isWinner': true,
          'message': '🎉 Congratulations! Bond #$bondNumber has won a prize!',
          'prizeAmount': 1500,
          'drawNumber': '245',
          'drawDate': 'December 2024',
        };
      } else {
        return {
          'isWinner': false,
          'message': 'Bond #$bondNumber is not a winner in recent draws.',
          'prizeAmount': 0,
        };
      }
    } catch (e) {
      throw Exception('Failed to check bond: $e');
    }
  }
}
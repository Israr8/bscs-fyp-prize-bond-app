import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/models/user_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  UserModel? get currentUser => _user;
  Stream<User?> get userStream => _auth.authStateChanges();

  bool _isRegistering = false;

  String _hashPin(String pin) {
    final cleanPin = pin.trim();
    final hash = sha256.convert(utf8.encode(cleanPin)).toString();
    return hash;
  }

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (_isRegistering) return;

      if (user != null) {
        try {
          await _loadUserData(user.uid);
        } catch (e) {
          debugPrint('Error loading user data from listener: $e');
        }
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;

        // Check user type first
        final userType = data['userType'] ?? 'normal';

        // If user is admin, skip approval check
        if (userType == 'admin') {
          // Load admin user data

          // Update last login for admin
          _user = UserModel.fromFirestore(data);
          await _firestore.collection('users').doc(uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });

          notifyListeners();
          return;
        }

        // For normal users, check approval status
        final isApproved = data['isApproved'] ?? false;
        final status = data['status'] ?? 'pending';

        if (!isApproved || status != 'approved') {
          await _auth.signOut();
          _user = null;
          notifyListeners();
          throw Exception('Account not approved. Please wait for admin approval.');
        }

        // Load normal user data
        _user = UserModel.fromFirestore(data);
        await _firestore.collection('users').doc(uid).update({

        // Update last login
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // Auto logout if user document doesn't exist
        await _auth.signOut();
        _user = null;
        notifyListeners();
        throw Exception('User data not found. Please contact admin.');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      rethrow;
    }
  }

  Future<void> registerWithEmailAndPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String mobileNo,
    required String pin,
    required String address,
    required String city,
    required String userType,
  }) async {
    _isRegistering = true;

    try {
      final String pinToStore;
      // Check kro Pin already hash to ni ha
      if (pin.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(pin)) {
        pinToStore = pin;
      } else {
        pinToStore = _hashPin(pin);
      }

      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user!.uid;

      final userData = {
        'uid': userId,
        'email': email.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'mobileNo': mobileNo.trim(),
        'pin': pinToStore,
        'address': address.trim(),
        'city': city.trim(),
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'savedBonds': [],
        'bondsCount': 0,
        'bondLimit': 1000,
        'package': 'FREE',
        'isPremium': false,
        'isApproved': userType == 'admin',
        'isActive': userType == 'admin',
        'status': userType == 'admin' ? 'approved' : 'pending',
      };

      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));

      await Future.delayed(const Duration(milliseconds: 500));
      await _auth.signOut();

      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Registration error: $e');
      try {
        await _auth.signOut();
      } catch (_) {}
      rethrow;
    } finally {
      _isRegistering = false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final storedPin = data['pin'] ?? '';

      // Check if stored PIN is already hashed
      final String enteredPinHash;
      if (storedPin.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(storedPin)) {
        enteredPinHash = _hashPin(pin);
      } else {
        enteredPinHash = pin;
      }
      return storedPin == enteredPinHash;
    } catch (e) {
      debugPrint('PIN verify error: $e');
      return false;
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Sign in with Firebase Auth
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user!.uid;

      // Get user data from Firestore
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        await _auth.signOut();
        throw Exception('User data not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final userModel = UserModel.fromFirestore(data);

      // Check if user is admin
      if (userModel.userType == 'admin') {
        _user = userModel;
        notifyListeners();
        return userModel;
      }

      // For normal users, check approval status
      if (!userModel.isApproved || userModel.status != 'approved') {
        await _auth.signOut();
        throw Exception('Your account is pending admin approval. You will receive an email when approved.');
      }

      _user = userModel;

      // Update last login
      await _firestore.collection('users').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message,
      );
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }


  // Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['userType'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  // Get user by ID (for admin panel)
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return UserModel.fromFirestore(data);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  // Get all pending users (for admin panel)
  Future<List<UserModel>> getPendingUsers() async {
    try {
      final query = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .where('userType', isEqualTo: 'normal')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending users: $e');
      return [];
    }
  }

  // Update user status (for admin panel)
  Future<void> updateUserStatus({
    required String userId,
    required String status,
    required bool isApproved,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'isApproved': isApproved,
        'isActive': isApproved,
      });

      // Get user email for notification
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'];

      // Send approval email notification
      final userName = '${userData['firstName']} ${userData['lastName']}';

      debugPrint('User status updated to: $status');
      await _sendApprovalEmail(userEmail, userName, status);
    } catch (e) {
      debugPrint('Error updating user status: $e');
      rethrow;
    }
  }

  Future<void> _sendApprovalEmail(String email, String name, String status) async {
    debugPrint('Approval email to: $email');
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw Exception('Logout failed: $e');
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? mobileNo,
    String? address,
    String? city,
    String? pin,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final updates = <String, dynamic>{};

      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      if (mobileNo != null) updates['mobileNo'] = mobileNo;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;
      if (pin != null) {
        final cleanPin = pin.trim();
        updates['pin'] = _hashPin(cleanPin);
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      // Reload user data
      await _loadUserData(user.uid);
      debugPrint('Profile updated');
    } catch (e) {
      debugPrint('Profile update error: $e');
      rethrow;
    }
  }

  // Change PIN
  Future<void> changePin(String oldPin, String newPin) async {
    try {
      final user = _auth.currentUser;

      // Verify old PIN
      if (user == null) throw Exception('No user logged in');
      final isVerified = await verifyPin(oldPin);
      if (!isVerified) throw Exception('Old PIN is incorrect');
      final cleanNewPin = newPin.trim();
      await _firestore.collection('users').doc(user.uid).update({
        'pin': _hashPin(cleanNewPin),
      });
      debugPrint('PIN changed');
    } catch (e) {
      debugPrint('PIN change error: $e');
      rethrow;
    }
  }
}
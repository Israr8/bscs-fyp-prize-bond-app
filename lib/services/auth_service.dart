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

  // Hash PIN function
  String _hashPin(String pin) {
    // Trim and validate PIN
    final cleanPin = pin.trim();
    debugPrint('🔐 Hashing PIN: "$cleanPin"');
    final hash = sha256.convert(utf8.encode(cleanPin)).toString();
    debugPrint('🔐 Hash result: "$hash"');
    return hash;
  }

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (_isRegistering) {
        debugPrint('⚠️ Skipping auth listener during registration');
        return;
      }

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
          _user = UserModel.fromFirestore(data);

          // Update last login for admin
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

        // Update last login
        await _firestore.collection('users').doc(uid).update({
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
      debugPrint('🔄 Step 1: Creating Firebase Auth user...');
      final String pinToStore;
      // Check kro Pin already hash to ni ha
      if (pin.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(pin)) {
        // Ye already hashed hai - directly store karo
        pinToStore = pin;
        debugPrint('🔐 PIN already hashed: "$pinToStore"');
      } else {
        // Pin plain text ha esko hash krna ha yahan pr
        pinToStore = _hashPin(pin);
        debugPrint('🔐 Hashing plain PIN: "$pin" -> "$pinToStore"');
      }

      // Create Firebase Auth user
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user!.uid;
      debugPrint('✅ Firebase Auth user created: $userId');

      // Prepare user data - use pinToStore
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

      debugPrint('📤 Storing PIN hash: "$pinToStore"');

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));

      // Verify
      final savedDoc = await _firestore.collection('users').doc(userId).get();
      final savedData = savedDoc.data();
      debugPrint('✅ VERIFICATION - Stored PIN hash: "${savedData?['pin']}"');

      // Auto logout
      await Future.delayed(const Duration(milliseconds: 500));
      await _auth.signOut();
      debugPrint('✅ User logged out after registration');

      _user = null;
      notifyListeners();

      debugPrint('🎉 Registration completed successfully');
    } catch (e) {
      debugPrint('💥 Registration Error: $e');
      try {
        await _auth.signOut();
      } catch (_) {}
      rethrow;
    } finally {
      _isRegistering = false;
    }
  }

// verifyPin function
  Future<bool> verifyPin(String pin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ verifyPin: No user logged in');
        return false;
      }

      debugPrint('🔍 verifyPin: User UID = ${user.uid}');
      debugPrint('🔍 verifyPin: Entered PIN = "$pin"');

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        debugPrint('❌ verifyPin: User document not found');
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final storedPin = data['pin'] ?? '';

      // Check if stored PIN is already hashed
      final String enteredPinHash;

      if (storedPin.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(storedPin)) {
        // Stored PIN is hashed - hash the entered PIN
        enteredPinHash = _hashPin(pin);
        debugPrint('🔑 Entered PIN hashed: "$enteredPinHash"');
      } else {
        // Stored PIN is plain text - compare directly
        enteredPinHash = pin;
        debugPrint('⚠️ Stored PIN is plain text!');
      }

      debugPrint('💾 Stored PIN: "$storedPin"');
      debugPrint('🔑 Entered PIN hash: "$enteredPinHash"');

      final isValid = storedPin == enteredPinHash;
      debugPrint('✅ Match: $isValid');

      return isValid;
    } catch (e) {
      debugPrint('❌ PIN verification error: $e');
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
      final userName = '${userData['firstName']} ${userData['lastName']}';

      // Send approval email notification
      await _sendApprovalEmail(userEmail, userName, status);

      debugPrint('✅ User status updated to: $status');
    } catch (e) {
      debugPrint('Error updating user status: $e');
      rethrow;
    }
  }

  Future<void> _sendApprovalEmail(String email, String name, String status) async {
    // Implement email sending logic here
    debugPrint('📧 Approval email would be sent to: $email');
    debugPrint('Subject: Your account has been $status');
  }

  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out...');
      await _auth.signOut();
      _user = null;
      notifyListeners();
      debugPrint('✅ Sign out successful');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
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

      debugPrint('✅ Profile updated successfully');
    } catch (e) {
      debugPrint('❌ Profile update error: $e');
      rethrow;
    }
  }

  // Change PIN
  Future<void> changePin(String oldPin, String newPin) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Verify old PIN
      final isVerified = await verifyPin(oldPin);
      if (!isVerified) {
        throw Exception('Old PIN is incorrect');
      }

      // Update to new PIN
      final cleanNewPin = newPin.trim();
      await _firestore.collection('users').doc(user.uid).update({
        'pin': _hashPin(cleanNewPin),
      });

      debugPrint('✅ PIN changed successfully');
    } catch (e) {
      debugPrint('❌ PIN change error: $e');
      rethrow;
    }
  }
}
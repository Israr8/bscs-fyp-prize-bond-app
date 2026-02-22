import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String mobileNo;
  final String pin; // Hashed 4-digit PIN
  final String address;
  final String city;
  final String userType; // 'admin' or 'normal'
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String package;
  final int bondLimit;
  final int bondsCount;
  final List<String> savedBonds;
  final bool isPremium;
  final bool isApproved; // New field for admin approval
  final bool isActive;
  final String status; // 'pending', 'approved', 'rejected'

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.mobileNo,
    required this.pin,
    required this.address,
    required this.city,
    required this.userType,
    this.photoUrl,
    required this.createdAt,
    this.lastLogin,
    this.package = 'FREE',
    this.bondLimit = 1000,
    this.bondsCount = 0,
    this.savedBonds = const [],
    this.isPremium = false,
    this.isApproved = false,
    this.isActive = true,
    this.status = 'pending',
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      mobileNo: data['mobileNo']?.toString() ?? '',
      pin: data['pin']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      userType: data['userType']?.toString() ?? 'normal',
      photoUrl: data['photoUrl']?.toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLogin: data['lastLogin'] is Timestamp
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
      package: data['package'] ?? 'FREE',
      bondLimit: data['bondLimit'] ?? 1000,
      bondsCount: data['bondsCount'] ?? 0,
      savedBonds: data['savedBonds'] is List
          ? List<String>.from(data['savedBonds'])
          : [],
      isPremium: data['isPremium'] ?? false,
      isApproved: data['isApproved'] ?? false,
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'mobileNo': mobileNo,
      'pin': pin,
      'address': address,
      'city': city,
      'userType': userType,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'package': package,
      'bondLimit': bondLimit,
      'bondsCount': bondsCount,
      'savedBonds': savedBonds,
      'isPremium': isPremium,
      'isApproved': isApproved,
      'isActive': isActive,
      'status': status,
  // Helper method to check if user is admin
    };
  }

  // Helper method to check if registration is approved

  bool get isAdmin => userType == 'admin';
  bool get canLogin => isApproved && isActive && status == 'approved';
}
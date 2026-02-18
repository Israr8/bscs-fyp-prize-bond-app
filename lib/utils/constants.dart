import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF1A73E8);
  static const Color secondaryColor = Color(0xFF34A853);
  static const Color accentColor = Color(0xFFFBBC05);
  static const Color dangerColor = Color(0xFFEA4335);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF202124);
  static const Color textSecondaryColor = Color(0xFF5F6368);
}

class AppStrings {
  static const String appName = 'Pakbond';
  static const String appTagline = 'Prize Bond Checking App';

  // Features
  static const String quickCheck = 'Quick Check';
  static const String quickScan = 'Quick Scan';
  static const String myBonds = 'My Bonds';
  static const String lockers = 'Lockers';
  static const String drawLists = 'Draw Lists';
  static const String marketplace = 'Marketplace';
  static const String missedPrizes = 'Missed Prizes';
  static const String resultsOnCall = 'Results on Call';

  // Package info
  static const String packageFree = 'FREE';
  static const String packageExpiry = '∞';
  static const String spaceUsed = '0/1,000';

  // Draw denominations
  static const List<String> denominations = [
    'Rs. 100',
    'Rs. 200',
    'Rs. 750',
    'Rs. 1500',
    'Rs. 7,500',
    'Rs. 15,000',
    'Rs. 25,000',
    'Rs. 40,000',
  ];

  // Cities for draws
  static const List<String> cities = [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
    'All Cities',
  ];
}



class AppEndpoints {
  static const String baseUrl = 'https://api.pakbond.com';
  static const String drawResults = '$baseUrl/api/draws';
  static const String checkBond = '$baseUrl/api/check';
  static const String marketListings = '$baseUrl/api/marketplace';
  static const String pdfDownload = '$baseUrl/api/pdf';
}

class AppPreferences {
  static const String userLoggedIn = 'user_logged_in';
  static const String userEmail = 'user_email';
  static const String userName = 'user_name';
  static const String userToken = 'user_token';
  static const String lastSyncDate = 'last_sync_date';
  static const String savedBondsCount = 'saved_bonds_count';
  static const String notificationsEnabled = 'notifications_enabled';
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
class Helpers {
  // Format currency
  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'Rs. ',
      decimalDigits: 0,
    ).format(amount);
  }

  // Format date
  static String formatDate(DateTime date, {bool showTime = false}) {
    if (showTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  // Show snackbar
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Validate bond number
  static bool isValidBondNumber(String number) {
    if (number.isEmpty) return false;

    // Remove any spaces or dashes
    final cleaned = number.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it's numeric
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return false;

    // Check length
    return cleaned.length == 6;
  }

  // Validate email
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);
  }

  // Validate phone number (Pakistani)
  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s-+]'), '');
    return RegExp(r'^(\+92|0)[0-9]{10}$').hasMatch(cleaned);
  }

  // Get denomination amount from string
  static double getDenominationAmount(String denomination) {
    final matches = RegExp(r'Rs\.?\s*([\d,]+)').firstMatch(denomination);
    if (matches != null && matches.groupCount > 0) {
      final amountStr = matches.group(1)!.replaceAll(',', '');
      return double.tryParse(amountStr) ?? 0;
    }
    return 0;
  }

  // Generate random bond number for testing
  static String generateRandomBondNumber() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 1000000000).toString().padLeft(9, '0');
  }

  // Calculate winning probability (mock)
  static double calculateWinningProbability(String denomination) {
    final amount = getDenominationAmount(denomination);

    // Mock probabilities based on denomination
    if (amount <= 200) return 0.0001;
    if (amount <= 1500) return 0.0002;
    if (amount <= 7500) return 0.0003;
    if (amount <= 15000) return 0.0004;
    if (amount <= 25000) return 0.0005;
    return 0.0006;
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Debounce function
  static Function debounce(Function fn, Duration delay) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(delay, () => fn());
    };
  }

  // Throttle function
  static Function throttle(Function fn, Duration duration) {
    bool enable = true;
    return () {
      if (enable) {
        fn();
        enable = false;
        Timer(duration, () => enable = true);
      }
    };
  }
}

// Extension for String
extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String maskBondNumber() {
    if (length < 4) return this;
    return '${substring(0, 2)}****${substring(length - 2)}';
  }
}

// Extension for DateTime
extension DateTimeExtensions on DateTime {
  String toFormattedString() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool isThisWeek() {
    final now = DateTime.now();
    final difference = now.difference(this);
    return difference.inDays <= 7;
  }
}

// Extension for List
extension ListExtensions<T> on List<T> {
  List<T> safeSublist(int start, [int? end]) {
    if (isEmpty) return [];
    final safeStart = start.clamp(0, length);
    final safeEnd = (end ?? length).clamp(0, length);
    if (safeStart >= safeEnd) return [];
    return sublist(safeStart, safeEnd);
  }
}

// lib/widgets/admin_only_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOnlyWrapper extends StatefulWidget {
  final Widget child;
  final String requiredPermission;

  const AdminOnlyWrapper({
    super.key,
    required this.child,
    this.requiredPermission = '',
  });

  @override
  State<AdminOnlyWrapper> createState() => _AdminOnlyWrapperState();
}

class _AdminOnlyWrapperState extends State<AdminOnlyWrapper> {
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final isAdmin = userData?['isAdmin'] == true;

      // Check specific permission if required
      if (widget.requiredPermission.isNotEmpty) {
        final permissions = List<String>.from(userData?['permissions'] ?? []);
        _hasPermission = permissions.contains(widget.requiredPermission);
      }

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Admin Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('This area is restricted to administrators only.'),
              SizedBox(height: 20),
              Text('Please contact system administrator.'),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission && widget.requiredPermission.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permission Denied')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                'Missing Permission: ${widget.requiredPermission}',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
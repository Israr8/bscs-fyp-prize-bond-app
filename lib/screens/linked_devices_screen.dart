// lib/screens/linked_devices_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _addCurrentDevice();
  }

  Future<void> _addCurrentDevice() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current device info
      String deviceId = '';
      String deviceName = '';
      String platform = '';

      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.model;
        platform = 'Android';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
        deviceName = iosInfo.name ?? 'iOS Device';
        platform = 'iOS';
      }

      // Check if device already exists
      final existingDevice = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (existingDevice.docs.isEmpty && deviceId.isNotEmpty) {
        // Add new device
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .add({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
          'lastLogin': DateTime.now(),
          'isCurrent': true,
          'createdAt': DateTime.now(),
        });
      } else if (existingDevice.docs.isNotEmpty) {
        // Update last login
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(existingDevice.docs.first.id)
            .update({
          'lastLogin': DateTime.now(),
          'isCurrent': true,
        });
      }
    } catch (e) {
      debugPrint('Error adding device: $e');
    }
  }

  Future<void> _loadDevices() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .orderBy('lastLogin', descending: true)
          .get();

      setState(() {
        _devices = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .delete();

      // Reload devices
      await _loadDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logoutAllDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout All Devices'),
        content: const Text('This will log you out from all devices except this one. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        // Remove all devices except current
        for (var device in _devices) {
          if (device['isCurrent'] != true) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('devices')
                .doc(device['id'])
                .delete();
          }
        }

        // Reload devices
        await _loadDevices();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out from all other devices'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Devices'),
        actions: [
          if (_devices.length > 1)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout All Devices',
              onPressed: _logoutAllDevices,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(
        child: Text('No devices linked'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final isCurrent = device['isCurrent'] == true;
    final lastLogin = (device['lastLogin'] as Timestamp).toDate();
    final platform = device['platform'] ?? 'Unknown';
    final deviceName = device['deviceName'] ?? 'Unknown Device';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCurrent ? AppColors.primaryColor.withOpacity(0.05) : null,
      child: ListTile(
        leading: Icon(
          platform == 'Android' ? Icons.android : Icons.phone_iphone,
          color: isCurrent ? AppColors.primaryColor : Colors.grey,
        ),
        title: Text(
          deviceName,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform: $platform'),
            Text('Last login: ${DateFormat('MMM dd, hh:mm a').format(lastLogin)}'),
            if (isCurrent)
              const Chip(
                label: Text('Current Device'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white, fontSize: 10),
              ),
          ],
        ),
        trailing: !isCurrent
            ? IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeDevice(device['id']),
        )
            : null,
      ),
    );
  }
}
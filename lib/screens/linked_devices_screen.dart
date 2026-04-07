// lib/screens/linked_devices_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app/utils/constants.dart';
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
    _initDevices();
  }

  Future<void> _initDevices() async {
    await _addCurrentDevice();
    await _loadDevices();
  }

  Future<void> _addCurrentDevice() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String deviceId = '';
      String deviceName = '';
      String platform = '';

      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        final brand = androidInfo.brand?.isNotEmpty == true ? androidInfo.brand! : '';
        final model = androidInfo.model?.isNotEmpty == true ? androidInfo.model! : '';
        deviceName = brand.isNotEmpty && model.isNotEmpty
            ? '$brand $model'
            : (model.isNotEmpty ? model : 'Android Device');
        platform = 'Android';
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
        deviceName = (iosInfo.name?.isNotEmpty == true ? iosInfo.name! : null) ?? 'iOS Device';
        platform = 'iOS';
      }

      if (deviceId.isEmpty) return;

      final devicesRef = _firestore.collection('users').doc(user.uid).collection('devices');
      final existingDevice = await devicesRef.where('deviceId', isEqualTo: deviceId).get();

      final now = FieldValue.serverTimestamp();

      if (existingDevice.docs.isEmpty) {
        final allDevices = await devicesRef.get();
        if (allDevices.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in allDevices.docs) {
            batch.update(doc.reference, {'isCurrent': false});
          }
          await batch.commit();
        }
        await devicesRef.add({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
          'lastLogin': now,
          'isCurrent': true,
          'createdAt': now,
        });
      } else {
        final batch = _firestore.batch();
        for (var doc in existingDevice.docs) {
          batch.update(doc.reference, {'lastLogin': now, 'isCurrent': true});
        }
        final allDevices = await devicesRef.get();
        for (var doc in allDevices.docs) {
          if (!existingDevice.docs.any((d) => d.id == doc.id)) {
            batch.update(doc.reference, {'isCurrent': false});
          }
        }
        await batch.commit();
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
          .limit(20)
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
    DateTime lastLogin = DateTime.now();
    if (device['lastLogin'] != null) {
      if (device['lastLogin'] is Timestamp) {
        lastLogin = (device['lastLogin'] as Timestamp).toDate();
      } else if (device['lastLogin'] is DateTime) {
        lastLogin = device['lastLogin'] as DateTime;
      }
    }
    final platform = device['platform'] ?? 'Unknown';
    final deviceName = device['deviceName']?.toString().trim().isNotEmpty == true
        ? device['deviceName'].toString()
        : 'This device';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCurrent ? AppColors.primaryColor.withValues(alpha:0.05) : null,
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
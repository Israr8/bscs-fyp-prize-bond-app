// lib/services/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final ValueNotifier<List<Map<String, dynamic>>> notificationsList =
  ValueNotifier<List<Map<String, dynamic>>>([]);

  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Completer<bool> _initialized = Completer<bool>();

  static Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      // Save token to Firebase
      await _saveFCMTokenToFirebase(token);

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Create notification channel for Android
      await _createNotificationChannel();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }

        if (message.notification != null) {
          showNotification(
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? '',
          );
        }

        // Fetch updated notifications
        _fetchNotifications();
      });

      // Handle when app is opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      // Handle when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      // Load existing notifications
      await _fetchNotifications();

      _initialized.complete(true);
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
      _initialized.completeError(e);
    }
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'prize_bond_channel',
      'Prize Bond Notifications',
      description: 'Notifications for prize bond updates and winners',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _saveFCMTokenToFirebase(String? token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'fcmTokenUpdated': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('FCM Token saved to Firebase for user: ${user.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token to Firebase: $e');
      }
    }
  }

  static void _handleMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('A new onMessageOpenedApp event was published!');
      print('Message data: ${message.data}');
    }

    // You can handle navigation based on message data here
    // For example: navigate to specific screen
  }

  static Future<void> _fetchNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.uid)
          .collection('user_notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      notificationsList.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'type': data['type'] ?? '',
          'isRead': data['isRead'] ?? false,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'bondNumber': data['bondNumber'],
          'drawNumber': data['drawNumber'],
          'prizeAmount': data['prizeAmount'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'prize_bond_channel',
        'Prize Bond Notifications',
        channelDescription: 'Notifications for prize bond updates',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        styleInformation: BigTextStyleInformation(body),
      );

      final NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
        payload: data != null ? data.toString() : 'prize_bond_notification',
      );

      // Also save to Firestore
      await _saveNotificationToFirestore(title, body, data);

    } catch (e) {
      if (kDebugMode) {
        print('Error showing notification: $e');
      }
    }
  }

  static Future<void> _saveNotificationToFirestore(
      String title,
      String body,
      Map<String, dynamic>? data,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notificationData = {
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': data?['type'] ?? 'SYSTEM',
      };

      if (data != null) {
        notificationData.addAll(data);
      }

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.uid)
          .collection('user_notifications')
          .add(notificationData);

      await _fetchNotifications();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notification to Firestore: $e');
      }
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.uid)
          .collection('user_notifications')
          .doc(notificationId)
          .update({'isRead': true});

      await _fetchNotifications();
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  static Future<void> clearAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.uid)
          .collection('user_notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      notificationsList.value = [];
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing notifications: $e');
      }
    }
  }

  static Future<void> clearNotification(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.uid)
          .collection('user_notifications')
          .doc(notificationId)
          .delete();

      await _fetchNotifications();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing notification: $e');
      }
    }
  }

  static Future<bool> isInitialized() async {
    return _initialized.future;
  }
}
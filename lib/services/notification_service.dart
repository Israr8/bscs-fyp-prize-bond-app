import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final ValueNotifier<List<Map<String, dynamic>>> notificationsList =
  ValueNotifier<List<Map<String, dynamic>>>([]);

  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Completer<bool> _initialized = Completer<bool>();

  static Future<void> initialize() async {
    try {
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

      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }

      await _saveFCMTokenToFirebase(token);

      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

      await _createNotificationChannel();

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

        _fetchNotifications();
      });

      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      await _fetchNotifications();

      _startDrawAnnouncementsListener();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _startWinnerAlertsListener(user.uid);

      _initialized.complete(true);
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
      _startDrawAnnouncementsListener();
      if (!_initialized.isCompleted) _initialized.complete(true);
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
          'createdAt': _parseCreatedAt(data['createdAt']),
          'bondNumber': data['bondNumber'],
          'drawNumber': data['drawNumber'],
          'prizeAmount': data['prizeAmount'],
          'prizeType': data['prizeType'],
          'denomination': data['denomination'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
    }
  }

  static DateTime _parseCreatedAt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }

  // Call after login or when opening the notifications screen.
  static Future<void> refreshInbox() => _fetchNotifications();

  // Adds a row under the buyer's notification inbox when a sale completes.
  static Future<bool> appendMarketplacePurchaseForBuyer({
    required String buyerUid,
    required String bondNumber,
    required String marketplaceItemId,
    double? askingPrice,
  }) async {
    try {
      final title = 'Bond purchase completed';
      final body =
          'Bond #$bondNumber was added to My Bonds. The seller marked the sale complete.';
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(buyerUid)
          .collection('user_notifications')
          .add({
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'MARKETPLACE_PURCHASE',
        'bondNumber': bondNumber,
        'marketplaceItemId': marketplaceItemId,
        if (askingPrice != null) 'askingPrice': askingPrice,
      });

      final current = FirebaseAuth.instance.currentUser;
      if (current != null && current.uid == buyerUid) {
        await _fetchNotifications();
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('appendMarketplacePurchaseForBuyer error: $e');
      }
      return false;
    }
  }

  static const String _keyLastSeenAnnouncementId = 'last_seen_draw_announcement_id';
  static String? _winnerListenerUid;

  static void _startDrawAnnouncementsListener() {
    FirebaseFirestore.instance
        .collection('draw_announcements')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          if (snapshot.docs.isEmpty) return;
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final doc = snapshot.docs.first;
          final data = doc.data();
          final prefs = await SharedPreferences.getInstance();
          final lastId = prefs.getString(_keyLastSeenAnnouncementId);
          if (lastId == null || doc.id != lastId) {
            final String title = 'New Draw Uploaded';
            final String body = data['message']?.toString() ?? 'A new draw has been uploaded.';
            await showNotification(title: title, body: body, data: {
              'type': 'DRAW_ANNOUNCEMENT',
              'drawNumber': data['drawNumber'],
              'denomination': data['denomination'],
            });
          }
          await prefs.setString(_keyLastSeenAnnouncementId, doc.id);
        } catch (e) {
          if (kDebugMode) print('Draw announcements listener error: $e');
        }
      },
      onError: (e) {
        if (kDebugMode) print('Draw announcements stream error: $e');
      },
    );
  }

  static void _startWinnerAlertsListener(String uid) {
    FirebaseFirestore.instance
        .collection('winner_notifications')
        .doc(uid)
        .collection('alerts')
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null || user.uid != uid) return;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final String title = 'Winning bond';
            final String body = data['message']?.toString() ?? 'Your bond matched this draw.';
            await showNotification(title: title, body: body, data: {
              'type': 'WINNER',
              'bondNumber': data['bondNumber'],
              'drawNumber': data['drawNumber'],
              'denomination': data['denomination'],
              'prizeType': data['prizeType'],
            });
            await doc.reference.delete();
          }
        } catch (e) {
          if (kDebugMode) print('Winner alerts listener error: $e');
        }
      },
      onError: (e) {
        if (kDebugMode) print('Winner alerts stream error: $e');
      },
    );
  }

  static void startWinnerListenerIfNeeded() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (_winnerListenerUid == user.uid) return;
      _winnerListenerUid = user.uid;
      _startWinnerAlertsListener(user.uid);
    } catch (e) {
      if (kDebugMode) print('startWinnerListenerIfNeeded error: $e');
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
        styleInformation: BigTextStyleInformation(body),
      );

      final NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

      final nid = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
      await _flutterLocalNotificationsPlugin.show(
        nid,
        title,
        body,
        platformChannelSpecifics,
        payload: data != null ? data.toString() : 'prize_bond_notification',
      );

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
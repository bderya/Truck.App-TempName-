import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM token is saved to users.fcm_token. Call [init] after Firebase.initializeApp() in main.
/// When a new chat message is inserted, the backend (Edge Function) sends a push to the recipient's token.
Future<void> initPushNotifications({required int userId}) async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) {
    await Supabase.instance.client.from('users').update({
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // When app is in foreground and a message is received (e.g. user not on chat screen).
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Optional: show in-app banner or local notification.
    // final title = message.notification?.title ?? 'New message';
    // final body = message.notification?.body ?? '';
  });
}

/// Call when user signs out to stop sending pushes to this device.
Future<void> clearPushToken(int userId) async {
  await Supabase.instance.client.from('users').update({
    'fcm_token': null,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', userId);
}

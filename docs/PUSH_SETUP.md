# Push notifications (FCM) for chat

When a new message is inserted into `messages`, the backend can send an FCM notification to the recipient so they see it even when not on the chat screen.

## 1. Firebase project

- Create a project in [Firebase Console](https://console.firebase.google.com).
- Add Android and/or iOS app, download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

## 2. Flutter

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure
```

Then in `lib/main.dart`, before `runApp`, add:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// inside main(), after WidgetsFlutterBinding.ensureInitialized():
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

## 3. Supabase

- Run migrations so `users.fcm_token` and `messages` table exist.
- Create a **Database Webhook**: table `messages`, event **Insert**, URL = your Edge Function URL (e.g. `https://<ref>.supabase.co/functions/v1/send-chat-push`).
- Deploy the Edge Function `send-chat-push` and set the secret `FCM_SERVER_KEY` (Firebase Console → Project settings → Cloud Messaging → Server key).

After this, when a user is authenticated the app registers their FCM token in `users.fcm_token`. New chat messages trigger the webhook and the function sends a push to the recipient.

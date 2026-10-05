import 'package:firebase_core/firebase_core.dart';

class Config {
  static const api = String.fromEnvironment('API_BASE_URL');
  static const firebaseKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const iosBundle = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  static bool get cloudConfigured =>
      [firebaseKey, appId, projectId, senderId].every((s) => s.isNotEmpty);
  static FirebaseOptions get firebase => FirebaseOptions(
    apiKey: firebaseKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain,
    iosBundleId: iosBundle.isEmpty ? null : iosBundle,
  );
}

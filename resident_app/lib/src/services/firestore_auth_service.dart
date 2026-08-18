import 'package:firebase_auth/firebase_auth.dart';

/// Compatibility accessor for older data services. Authentication itself is
/// handled exclusively by [FirebaseAuthService] using Firebase Phone Auth.
class FirestoreAuthService {
  static final FirestoreAuthService instance = FirestoreAuthService._internal();
  factory FirestoreAuthService() => instance;
  FirestoreAuthService._internal();

  Future<String?> getCurrentUserId() async =>
      FirebaseAuth.instance.currentUser?.uid;

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}

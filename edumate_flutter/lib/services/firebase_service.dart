import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/study_models.dart';

class FirebaseService {
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _ready = Firebase.apps.isNotEmpty;
      debugPrint('[EduMate] Firebase ready: $_ready');
    } catch (error) {
      // A missing google-services.json is expected for the zero-config demo.
      _ready = false;
      debugPrint('[EduMate] Firebase not configured; using local demo: $error');
    }
  }

  static Future<UserCredential> signInWithEmail(String email, String password) {
    if (!isReady) throw StateError('Firebase is not configured yet.');
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<UserCredential> createAccount(
    String email,
    String password,
  ) {
    if (!isReady) throw StateError('Firebase is not configured yet.');
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<UserCredential?> signInWithGoogle() async {
    if (!isReady) throw StateError('Firebase is not configured yet.');
    final account = await GoogleSignIn().signIn();
    if (account == null) return null;
    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<StudentProfile?> loadProfile(String uid) async {
    if (!isReady || uid.startsWith('local-')) return null;
    try {
      final document = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = document.data();
      if (data == null) return null;
      return StudentProfile.fromMap({...data, 'uid': uid});
    } catch (error) {
      debugPrint('[EduMate] Profile cloud load skipped: $error');
      return null;
    }
  }

  static Future<void> saveProfile(StudentProfile profile) async {
    if (!isReady || profile.uid.startsWith('local-')) return;
    await FirebaseFirestore.instance.collection('users').doc(profile.uid).set(
      {
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<String> storageDownloadUrl(String path) async {
    if (!isReady) throw StateError('Firebase Storage is not configured.');
    return FirebaseStorage.instance.ref(path).getDownloadURL();
  }

  static Future<List<ChatMessage>> loadChat(String uid, String key) async {
    if (!isReady || uid.startsWith('local-')) return [];
    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_sessions')
          .doc(key)
          .get();
      final raw = document.data()?['messages'];
      if (raw is! List) return [];
      return raw.whereType<Map>().map(ChatMessage.fromMap).toList();
    } catch (error) {
      debugPrint('[EduMate] Chat cloud load skipped: $error');
      return [];
    }
  }

  static Future<void> saveChat(String uid, String key, List<ChatMessage> messages) async {
    if (!isReady || uid.startsWith('local-')) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_sessions')
          .doc(key)
          .set({
        'messages': messages.map((message) => message.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('[EduMate] Chat cloud sync skipped: $error');
    }
  }

  static Future<void> saveQuizResult(String uid, Map<String, dynamic> result) async {
    if (!isReady || uid.startsWith('local-')) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quiz_history')
          .add({...result, 'createdAt': FieldValue.serverTimestamp()});
    } catch (error) {
      debugPrint('[EduMate] Quiz cloud sync skipped: $error');
    }
  }

  static Future<void> signOut() async {
    if (!isReady) return;
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (error) {
      debugPrint('[EduMate] Sign out warning: $error');
    }
  }
}

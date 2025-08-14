import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;

  User? get user => _user;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> saveUserToken(String userId) async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
      print("✅ User FCM Token updated.");
    }
  }

  /// **Sign Up with Role (Patient, Doctor, Admin)**
  Future<String?> signUp(String email, String password, String role, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection("users").doc(user.uid).set({
          "email": email,
          "role": role,
          "uid": user.uid,
          "name": name,
        });

        await saveUserToken(user.uid); // ✅ Save the FCM Token
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return "Password should be at least 6 characters.";
      } else if (e.code == 'email-already-in-use') {
        return "The email is already registered. Try logging in.";
      } else {
        return e.message ?? "An unexpected error occurred.";
      }
    } catch (e) {
      return "Something went wrong. Please try again.";
    }
  }

  /// **Sign In**
  Future<String?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        await saveUserToken(user.uid); // ✅ Save the FCM Token
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// **Google Sign-In**
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Google Sign-In canceled";

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection("users").doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection("users").doc(user.uid).set({
            "email": user.email,
            "role": "Patient",
            "uid": user.uid,
          });
        }

        await saveUserToken(user.uid); // ✅ Save the FCM Token
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// **Sign Out**
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// **Get User Role**
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection("users").doc(uid).get();
      return userDoc.exists ? userDoc["role"] : null;
    } catch (e) {
      return null;
    }
  }
}

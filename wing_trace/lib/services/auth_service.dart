import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Sign Up (Create Account & Store in Database)
  Future<String?> signUp(String email, String password, String name, String role) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;

      // Save user details + role to Firestore
      await _db.collection('users').doc(user!.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'role': role, // <--- This saves 'farmer' or 'officer'
        'created_at': FieldValue.serverTimestamp(),
        'owned_devices': [],
        'hasCompletedSetup': false
      });

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // 2. Sign In
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // 3. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 4. Get Current User ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // 5. Password Reset Logic
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success (null means no error)
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error (e.g., "User not found")
    }
  }
}
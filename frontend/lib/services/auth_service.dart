import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user's ID token
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _createOrUpdateUserDocument(credential.user!);
    return credential;
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String? displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    if (displayName != null) {
      await credential.user?.updateDisplayName(displayName);
    }
    
    await _createOrUpdateUserDocument(credential.user!);
    return credential;
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    if (googleUser == null) {
      throw AuthException(
        code: 'sign_in_cancelled',
        message: 'Google sign in was cancelled',
      );
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _createOrUpdateUserDocument(userCredential.user!);
    return userCredential;
  }

  /// Send OTP to phone number
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerify,
      verificationFailed: onError,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify phone OTP and sign in
  Future<UserCredential> verifyPhoneOtp(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    
    final userCredential = await _auth.signInWithCredential(credential);
    await _createOrUpdateUserDocument(userCredential.user!);
    return userCredential;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      // Create new user document
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userRef.set(newUser.toFirestore());
    } else {
      // Update existing user document
      await userRef.update({
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get user model from Firestore
  Future<UserModel?> getUserModel() async {
    if (currentUser == null) return null;
    
    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    if (!doc.exists) return null;
    
    return UserModel.fromFirestore(doc);
  }
}

class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  @override
  String toString() => message;
}

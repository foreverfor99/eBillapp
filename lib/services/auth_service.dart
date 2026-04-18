import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_client.dart';

class AuthOperationException implements Exception {
  const AuthOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const String usersCollection = 'users';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get userStream => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  String toUserMessage(Object error) {
    if (error is AuthOperationException) return error.message;
    return error.toString();
  }

  // ---------- AUTH ----------

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<String> register({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await _firestore.collection(usersCollection).doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'phoneNumber': phoneNumber,
        'emailOtpVerified': true, // Auto-verify
        'loginOtpPending': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<void> signOut() async => _auth.signOut();

  // ---------- Firestore helpers ----------

  Future<void> ensureCurrentUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection(usersCollection).doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'emailOtpVerified': true,
        'loginOtpPending': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  Future<void> deleteCurrentUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection(usersCollection).doc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthOperationException('هذه العملية تتطلب تسجيل دخول حديث. يرجى الخروج والدخول مرة أخرى.');
      }
      throw AuthOperationException(_handleAuthException(e));
    }
  }

  // ---------- Email OTP (Node server: /v1/email-otp) ----------

  Future<void> sendEmailOtpForEmail(String email) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthOperationException('يجب تسجيل الدخول أولاً.');
    }
    try {
      final ApiClient client = ApiClient();
      await client.post('/v1/email-otp/send', <String, dynamic>{
        'email': email.trim(),
      });
    } on ApiException catch (e) {
      throw AuthOperationException(e.message);
    }
  }

  Future<void> sendEmailOtp() async {
    final String? email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthOperationException('لا يوجد بريد مرتبط بالحساب.');
    }
    await sendEmailOtpForEmail(email);
  }

  Future<void> verifyEmailOtp(String code) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthOperationException('يجب تسجيل الدخول أولاً.');
    }
    try {
      final ApiClient client = ApiClient();
      await client.post('/v1/email-otp/verify', <String, dynamic>{
        'code': code.trim(),
      });
      await user.reload();
    } on ApiException catch (e) {
      throw AuthOperationException(e.message);
    }
  }

  Future<void> markLoginOtpPending(bool pending) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    await _firestore.collection(usersCollection).doc(user.uid).set(
      <String, dynamic>{
        'loginOtpPending': pending,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ---------- Phone verification (Firebase) ----------

  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onVerificationFailed,
  }) async {
    final Completer<void> done = Completer<void>();

    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 120),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.currentUser?.linkWithCredential(credential);
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException e) {
        onVerificationFailed(_handleAuthException(e));
        if (!done.isCompleted) {
          done.complete();
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
        if (!done.isCompleted) {
          done.complete();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!done.isCompleted) {
          done.complete();
        }
      },
    );

    return done.future;
  }

  Future<void> linkPhone(String verificationId, String smsCode) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AuthOperationException('يجب تسجيل الدخول أولاً.');
    }
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    await user.linkWithCredential(credential);
    await user.reload();
    final User? updated = _auth.currentUser;
    final String? phone = updated?.phoneNumber;
    await _firestore.collection(usersCollection).doc(user.uid).set(
      <String, dynamic>{
        if (phone != null && phone.isNotEmpty) 'phoneNumber': phone,
        'phoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String _handleAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'المستخدم غير موجود.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح.';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة.';
      default:
        return error.message ?? 'فشلت العملية.';
    }
  }
}

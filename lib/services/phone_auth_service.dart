import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PhoneAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> verifyPhoneNumber(
      String phoneNumber,
      BuildContext context, {
        required Function(String) onCodeSent,
        required Function(FirebaseAuthException) onError,
      }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android-e auto-retrieval hole auto sign-in hobe
        await _auth.currentUser?.linkWithCredential(credential);
      },
      verificationFailed: onError,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  static Future<bool> verifyOTP(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      // Current email account-er sathe phone number link kore deya
      await _auth.currentUser?.linkWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }
}
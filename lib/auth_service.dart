import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sms_autofill/sms_autofill.dart'; // Added this

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? _generatedOtp;
  static String? _currentPhone;

  // 1. Generate OTP and Send via BulkSMSBD
  Future<bool> sendOtp(String phoneNumber) async {
    _generatedOtp = (Random().nextInt(9000) + 1000).toString();
    _currentPhone = phoneNumber;

    // Grab the exact 11-character hash that identifies your specific Flutter app
    String appSignature = await SmsAutoFill().getAppSignature;

    final String apiKey = "wUpJNn3UpZqu9zzReiWo";
    final String senderId = "8809601004417";

    // Strict Google Format for Auto-Read: Starts with <#>, ends with App Hash
    String rawMessage = "<#> Your SpeakWallet login code is: $_generatedOtp\n$appSignature";
    final String message = Uri.encodeComponent(rawMessage);

    final String url = "https://bulksmsbd.net/api/smsapi?api_key=$apiKey&type=text&number=$phoneNumber&senderid=$senderId&message=$message";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        print("✅ OTP Sent! OTP: $_generatedOtp | Hash: $appSignature");
        return true;
      } else {
        print("❌ Failed to send SMS: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ API Error: $e");
      return false;
    }
  }

  // 2. Verify OTP and Login to Firebase
  Future<User?> verifyOtpAndLogin(String userEnteredOtp) async {
    if (userEnteredOtp == _generatedOtp && _currentPhone != null) {

      String dummyEmail = "$_currentPhone@speakwallet.com";
      String securePassword = "SW_${_currentPhone}_!Secure123";

      try {
        UserCredential cred;
        try {
          cred = await _auth.signInWithEmailAndPassword(email: dummyEmail, password: securePassword);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
            cred = await _auth.createUserWithEmailAndPassword(email: dummyEmail, password: securePassword);
          } else {
            rethrow;
          }
        }
        return cred.user;
      } catch (e) {
        print("❌ Firebase Auth Error: $e");
        return null;
      }
    } else {
      print("❌ OTP Mismatch! Expected: $_generatedOtp, Got: $userEnteredOtp");
      return null;
    }
  }
}
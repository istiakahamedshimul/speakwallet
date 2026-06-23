import 'dart:developer' as developer;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sms_autofill/sms_autofill.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? _generatedOtp;
  static String? _currentPhone;

  Future<bool> sendOtp(String phoneNumber) async {
    _generatedOtp = (Random().nextInt(9000) + 1000).toString();
    _currentPhone = phoneNumber;

    final String appSignature = await SmsAutoFill().getAppSignature;

    const String apiKey = "wUpJNn3UpZqu9zzReiWo";
    const String senderId = "8809601004417";

    final String rawMessage =
        "<#> Your SpeakWallet login code is: $_generatedOtp\n$appSignature";
    final String message = Uri.encodeComponent(rawMessage);

    final String url =
        "https://bulksmsbd.net/api/smsapi?api_key=$apiKey&type=text&number=$phoneNumber&senderid=$senderId&message=$message";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        developer.log("OTP Sent! OTP: $_generatedOtp | Hash: $appSignature",
            name: "AuthService");
        return true;
      } else {
        developer.log("Failed to send SMS: ${response.body}",
            name: "AuthService");
        return false;
      }
    } catch (e) {
      developer.log("API Error: $e", name: "AuthService");
      return false;
    }
  }

  Future<User?> verifyOtpAndLogin(String userEnteredOtp) async {
    if (userEnteredOtp == _generatedOtp && _currentPhone != null) {
      return _loginWithPhone(_currentPhone!);
    }

    developer.log(
        "OTP Mismatch! Expected: $_generatedOtp, Got: $userEnteredOtp",
        name: "AuthService");
    return null;
  }

  Future<User?> skipOtpAndLoginForTesting() async {
    if (_currentPhone == null) {
      developer.log("Cannot skip OTP before sending a code.",
          name: "AuthService");
      return null;
    }

    return _loginWithPhone(_currentPhone!);
  }

  Future<User?> _loginWithPhone(String phoneNumber) async {
    final String dummyEmail = "$phoneNumber@speakwallet.com";
    final String securePassword = "SW_${phoneNumber}_!Secure123";

    try {
      UserCredential cred;
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: dummyEmail,
          password: securePassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'invalid-email') {
          cred = await _auth.createUserWithEmailAndPassword(
            email: dummyEmail,
            password: securePassword,
          );
        } else {
          rethrow;
        }
      }
      return cred.user;
    } catch (e) {
      developer.log("Firebase Auth Error: $e", name: "AuthService");
      return null;
    }
  }
}

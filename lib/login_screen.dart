import 'package:flutter/material.dart';
import 'package:sms_autofill/sms_autofill.dart'; // Added this
import 'auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

// Added the "with CodeAutoFill" mixin here!
class _LoginScreenState extends State<LoginScreen> with CodeAutoFill {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    cancel(); // Stops listening for SMS when the screen is closed
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- AUTOMATIC OTP TRIGGER ---
  // This runs automatically the millisecond the SMS hits the phone
  @override
  void codeUpdated() {
    if (code != null && code!.length == 4) {
      setState(() {
        _otpController.text = code!;
      });
      // Auto-submit the code for a seamless experience
      _verifyCode();
    }
  }

  void _sendCode() async {
    String number = _phoneController.text.trim();
    if (number.isEmpty || number.length < 10) {
      _showSnackBar("Please enter a valid phone number", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    if (!number.startsWith("880")) {
      number = "880${number.replaceFirst(RegExp(r'^0+'), '')}";
    }

    bool success = await _authService.sendOtp(number);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isOtpSent = success;
    });

    if (success) {
      // START LISTENING FOR THE SMS!
      listenForCode();
      _showSnackBar("OTP Sent Successfully!", Colors.teal);
    } else {
      _showSnackBar("Failed to send OTP. Check connection.", Colors.redAccent);
    }
  }

  void _verifyCode() async {
    if (_otpController.text.trim().length != 4) {
      _showSnackBar("Please enter the 4-digit OTP", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    var user = await _authService.verifyOtpAndLogin(_otpController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      _showSnackBar("Logged in successfully!", Colors.teal);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } else {
      _showSnackBar("Invalid OTP. Please try again.", Colors.redAccent);
    }
  }

  void _skipVerificationForTesting() async {
    setState(() => _isLoading = true);
    var user = await _authService.skipOtpAndLoginForTesting();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      _showSnackBar("OTP skipped for testing.", Colors.teal);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } else {
      _showSnackBar(
          "Could not skip verification. Send OTP again.", Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(fontWeight: FontWeight.bold)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: color,
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal.shade900, Colors.teal.shade500],
          ),
        ),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded,
                        size: 80, color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "SpeakWallet",
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2),
                  ),
                  Text(
                    "AI Finance Tracker",
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.teal.shade100,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 50),
                  Container(
                    padding: EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isOtpSent ? "Verification" : "Welcome Back",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.teal.shade900),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _isOtpSent
                              ? "Auto-detecting the 4-digit code..."
                              : "Login with your phone number",
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 30),
                        if (!_isOtpSent) ...[
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber
                            ],
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5),
                            decoration: InputDecoration(
                              labelText: "Phone Number",
                              hintText: "017XXXXXXXX",
                              prefixIcon: Icon(Icons.phone_iphone_rounded,
                                  color: Colors.teal.shade700),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.teal.shade500, width: 2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade800,
                                elevation: 5,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 25,
                                      width: 25,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 3))
                                  : Text("Send OTP",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 32,
                                letterSpacing: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.teal.shade900),
                            decoration: InputDecoration(
                              counterText: "",
                              hintText: "----",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.teal.shade500, width: 2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade800,
                                elevation: 5,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 25,
                                      width: 25,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 3))
                                  : Text("Verify & Login",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                            ),
                          ),
                          SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _skipVerificationForTesting,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal.shade800,
                                side: BorderSide(
                                    color: Colors.teal.shade700, width: 1.4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                "Skip Verification",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              cancel(); // Stop listening if they go back
                              setState(() {
                                _isOtpSent = false;
                                _otpController.clear();
                              });
                            },
                            child: Text("Change Phone Number",
                                style: TextStyle(
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.bold)),
                          )
                        ]
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

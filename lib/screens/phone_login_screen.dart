import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  String _errorMessage = '';
  
  // Timer for cooldown
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _start = 60;
    _canResend = false;
    _timer?.cancel();
    
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
            _canResend = true;
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  Future<void> _verifyPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Please enter a phone number");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          // Android auto-retrieval or instant verification
          await _authService.signInWithCredential(credential);
           // Navigator pop handled by auth state listener in main or manual pop
           if (mounted) Navigator.pop(context); 
        },
        onVerificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? "Verification failed";
          });
        },
        onCodeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _codeSent = true;
            _verificationId = verificationId;
            _startTimer();
          });
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
       setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
    }
  }

  Future<void> _signInWithOTP() async {
     final otp = _otpController.text.trim();
     if (otp.isEmpty || _verificationId == null) {
       setState(() => _errorMessage = "Please enter the SMS code");
       return;
     }

     setState(() {
       _isLoading = true;
       _errorMessage = '';
     });

     try {
       PhoneAuthCredential credential = PhoneAuthProvider.credential(
         verificationId: _verificationId!,
         smsCode: otp,
       );
       await _authService.signInWithCredential(credential);
        // Success
       if (mounted) Navigator.pop(context);
     } catch (e) {
       setState(() {
         _isLoading = false;
         _errorMessage = "Invalid OTP or error signing in.";
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E), // Dark Navy
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
              const Color(0xFF6C5CE7).withOpacity(0.8), // Purple accent
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Align(
                    alignment: Alignment.centerLeft,
                     child: IconButton(
                       icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                       onPressed: () => Navigator.pop(context),
                     ),
                   ),
                   const SizedBox(height: 10),
                  // Logo
                  TweenAnimationBuilder<double>(
                     tween: Tween(begin: 0.0, end: 1.0),
                     duration: const Duration(milliseconds: 800),
                     curve: Curves.easeOutBack,
                     builder: (context, value, child) {
                       return Transform.scale(
                         scale: value,
                         child: Opacity(opacity: value, child: child),
                       );
                     },
                     child: Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.1),
                         shape: BoxShape.circle,
                        boxShadow: [
                             BoxShadow(
                               color: Colors.white.withOpacity(0.1),
                               blurRadius: 20,
                               spreadRadius: 2,
                             ),
                           ],
                       ),
                       child: const Icon(
                         Icons.phone_android_rounded,
                         size: 48,
                         color: Colors.white,
                       ),
                     ),
                   ),
                   const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    _codeSent ? "Verify Number" : "Phone Log In",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                   const SizedBox(height: 8),
                   Text(
                     _codeSent 
                       ? "Enter the code sent to ${_phoneController.text}"
                       : "Enter your phone number to continue",
                     textAlign: TextAlign.center,
                     style: TextStyle(
                       color: Colors.white.withOpacity(0.7),
                       fontSize: 16,
                     ),
                   ),
                   const SizedBox(height: 48),

                   // Card
                   Container(
                     padding: const EdgeInsets.all(32),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.95),
                       borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.2),
                             blurRadius: 30,
                             offset: const Offset(0, 15),
                           ),
                         ],
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         if (!_codeSent) ...[
                            // Phone Input
                             Container(
                               decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(16),
                                 color: Colors.grey.shade50,
                                 border: Border.all(color: Colors.grey.shade200),
                               ),
                               child: TextField(
                                 controller: _phoneController,
                                 keyboardType: TextInputType.phone,
                                 style: const TextStyle(
                                   fontSize: 18, 
                                   fontWeight: FontWeight.bold,
                                   color: Colors.black87
                                  ),
                                 decoration: InputDecoration(
                                   labelText: "Phone Number",
                                   hintText: "+1 650 555 3434",
                                   labelStyle: TextStyle(color: Colors.grey.shade600),
                                   prefixIcon: const Icon(Icons.dialpad, color: Color(0xFF6C5CE7)),
                                   border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(16),
                                     borderSide: BorderSide.none,
                                   ),
                                   filled: true,
                                   fillColor: Colors.transparent,
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                 ),
                               ),
                             ),
                         ] else ...[
                           // OTP Input
                            Container(
                               decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(16),
                                 color: Colors.grey.shade50,
                                 border: Border.all(color: Colors.grey.shade200),
                               ),
                               child: TextField(
                                 controller: _otpController,
                                 keyboardType: TextInputType.number,
                                 textAlign: TextAlign.center,
                                 style: const TextStyle(
                                   fontSize: 24, 
                                   fontWeight: FontWeight.bold,
                                   letterSpacing: 8,
                                   color: Colors.black87
                                  ),
                                 maxLength: 6,
                                 decoration: InputDecoration(
                                   counterText: "",
                                   hintText: "000000",
                                   hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 8),
                                   border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(16),
                                     borderSide: BorderSide.none,
                                   ),
                                   filled: true,
                                   fillColor: Colors.transparent,
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                 ),
                               ),
                             ),
                         ],

                         const SizedBox(height: 24),
                         
                         if (_errorMessage.isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 16.0),
                             child: Text(
                               _errorMessage,
                               style: const TextStyle(color: Colors.red, fontSize: 13),
                               textAlign: TextAlign.center,
                             ),
                           ),

                           // Action Button
                           Container(
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C5CE7).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading 
                                ? null 
                                : (_codeSent ? _signInWithOTP : _verifyPhone),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading 
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _codeSent ? "Verify & Sign In" : "Send Code",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                    ],
                                  ),
                            ),
                           ),

                           if (_codeSent) ...[
                             const SizedBox(height: 20),
                              TextButton(
                                onPressed: _canResend ? _verifyPhone : null,
                                child: Text(
                                  _canResend 
                                    ? "Resend Code"
                                    : "Resend Code in ${_start}s",
                                  style: TextStyle(
                                    color: _canResend ? const Color(0xFF6C5CE7) : Colors.grey,
                                  ),
                                ),
                              ),
                           ]
                       ],
                     ),
                   ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

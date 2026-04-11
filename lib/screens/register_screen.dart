import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  // Student specific controllers
  final _universityController = TextEditingController();
  final _collegeController = TextEditingController();
  final _departmentController = TextEditingController();
  final _semesterController = TextEditingController();

  final AuthService _authService = AuthService();
  
  bool isLoading = false;
  String errorMessage = '';
  String userRole = 'student'; // 'student', 'organizer', or 'admin'
  String registrationMethod = 'email'; // 'email' or 'phone'
  DateTime? dateOfBirth;

  // Phone Auth State
  bool _codeSent = false;
  String? _verificationId;
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _universityController.dispose();
    _collegeController.dispose();
    _departmentController.dispose();
    _semesterController.dispose();
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

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check password match for email registration
    if (registrationMethod == 'email' && 
        _passwordController.text != _confirmPasswordController.text) {
      setState(() => errorMessage = "Passwords do not match");
      return;
    }

    // If Phone mode and code NOT sent yet -> Send OTP
    if (registrationMethod == 'phone' && !_codeSent) {
      await _sendOTP();
      return;
    }

    // If Phone mode and code IS sent -> Verify OTP and Register
    if (registrationMethod == 'phone' && _codeSent) {
      await _verifyOTPAndRegister();
      return;
    }

    // If Email mode -> Register normally
    if (registrationMethod == 'email') {
      await _registerWithEmail();
    }
  }

  Future<void> _sendOTP() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        onVerificationCompleted: (PhoneAuthCredential credential) async {
         // Auto-resolution (not fully implemented for registration flow to prevent accidental skips, 
         // but we could use it to auto-fill)
        },
        onVerificationFailed: (FirebaseAuthException e) {
          setState(() {
            isLoading = false;
            errorMessage = e.message ?? "Verification failed";
          });
        },
        onCodeSent: (String verificationId, int? resendToken) {
          setState(() {
            isLoading = false;
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
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _verifyOTPAndRegister() async {
    if (_otpController.text.isEmpty) {
      setState(() => errorMessage = "Please enter the OTP");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Create credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      // Sign in (which registers the user in Auth if new)
      final userCredential = await _authService.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Save user data to Firestore
        await _saveUserData(user);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Invalid OTP or registration error:Str${e.toString()}";
      });
    }
  }

  Future<void> _registerWithEmail() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final user = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        await _saveUserData(user);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _saveUserData(User user) async {
    try {
      final userData = {
        'name': _nameController.text.trim(),
        'role': userRole,
        'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
        'createdAt': Timestamp.now(),
        'registrationMethod': registrationMethod,
      };

      if (registrationMethod == 'email') {
        userData['email'] = _emailController.text.trim();
        // Also save phone if it was sought for visitor, but currently visitor phone is same as login phone in this new flow?
        // If visitor selected email, we might still want phone. But let's stick to the selected method for primary ID.
        if ((userRole == 'organizer' || userRole == 'admin') && _phoneController.text.isNotEmpty) {
           userData['phone'] = _phoneController.text.trim();
        }
      } else {
        userData['phone'] = _phoneController.text.trim();
        if (_emailController.text.isNotEmpty) {
          userData['email'] = _emailController.text.trim(); // Optional email capture
        }
      }

      if (userRole == 'student') {
        userData.addAll({
          'university': _universityController.text.trim(),
          'collegeName': _collegeController.text.trim(),
          'department': _departmentController.text.trim(),
          'semester': _semesterController.text.trim(),
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        isLoading = false;
        // Proceed to home or pop
        Navigator.pop(context); 
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error saving profile: $e";
      });
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF3E0014), // Rustic Red
              const Color(0xFF1A000A), // Dark Burgundy
              const Color(0xFF000000), // Black
              const Color(0xFF7A002B), // Burgundy accent
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  
                  // Method Toggle (Email / Phone)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildMethodTab("Email", "email", Icons.email),
                        _buildMethodTab("Phone", "phone", Icons.phone),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role Selection
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.2),
                       borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildRoleTab("Student", "student"),
                        _buildRoleTab("Organizer", "organizer"),
                        _buildRoleTab("Admin", "admin"),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: "Full Name",
                          icon: Icons.person_outlined,
                          validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        // DOB
                        GestureDetector(
                          onTap: _selectDateOfBirth,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF6C5CE7)),
                                const SizedBox(width: 12),
                                Text(
                                  dateOfBirth == null ? "Date of Birth" : DateFormat('dd/MM/yyyy').format(dateOfBirth!),
                                  style: TextStyle(
                                    color: dateOfBirth == null ? Colors.grey.shade600 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Dynamic Fields based on Method ---
                        if (registrationMethod == 'email') ...[
                          _buildTextField(
                            controller: _emailController,
                            label: "Email",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v?.contains('@') ?? false) ? null : "Invalid email",
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            label: "Password",
                            icon: Icons.lock_outlined,
                            obscureText: true,
                            validator: (v) => (v!.length < 6) ? "Min 6 chars" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: "Confirm Password",
                            icon: Icons.lock_outlined,
                            obscureText: true,
                            validator: (v) => (v != _passwordController.text) ? "No match" : null,
                          ),
                          // If visitor, maybe ask for phone optionally or required?
                          // The original code asked for phone for visitors. Let's keep it.
                          if (userRole == 'organizer' || userRole == 'admin') ...[
                             const SizedBox(height: 20),
                             _buildTextField(
                               controller: _phoneController,
                               label: "Phone Number",
                               icon: Icons.phone_outlined,
                               keyboardType: TextInputType.phone,
                               validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                             ),
                          ]
                        ] else ...[
                          // Phone Method
                          _buildTextField(
                            controller: _phoneController,
                            label: "Phone Number",
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            enabled: !_codeSent, // Disable editing after code sent
                            validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                          ),
                          if (_codeSent) ...[
                             const SizedBox(height: 20),
                             _buildTextField(
                               controller: _otpController,
                               label: "OTP Code",
                               icon: Icons.password,
                               keyboardType: TextInputType.number,
                               validator: (v) => v?.length != 6 ? "Enter 6 digits" : null,
                             ),
                             Align(
                               alignment: Alignment.centerRight,
                               child: TextButton(
                                 onPressed: _canResend ? _sendOTP : null,
                                 child: Text(
                                   _canResend ? "Resend OTP" : "Resend in ${_start}s",
                                   style: TextStyle(
                                      color: _canResend ? const Color(0xFF6C5CE7) : Colors.grey,
                                   ),
                                 ),
                               ),
                             ),
                          ],
                        ],
                        
                        const SizedBox(height: 20),

                        // --- Student Specifics ---
                        if (userRole == 'student') ...[
                          _buildTextField(
                            controller: _universityController,
                            label: "University",
                            icon: Icons.school_outlined,
                            validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _collegeController,
                            label: "College Name",
                            icon: Icons.business_outlined,
                            validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _departmentController,
                            label: "Department",
                            icon: Icons.work_outline,
                            validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _semesterController,
                            label: "Semester",
                            icon: Icons.numbers_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => v?.isEmpty ?? true ? "Required" : null,
                          ),
                        ],

                        const SizedBox(height: 24),
                        
                        // Error Message
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                          ),

                        // Action Button
                        _buildActionButton(),
                        
                        const SizedBox(height: 16),
                        
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                              children: [
                                TextSpan(text: "Already have an account? "),
                                TextSpan(
                                  text: "Sign In",
                                  style: TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildMethodTab(String title, String method, IconData icon) {
    bool isSelected = registrationMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            registrationMethod = method;
            errorMessage = '';
            _codeSent = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF6C5CE7) : Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6C5CE7) : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String title, String role) {
    bool isSelected = userRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => userRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF6C5CE7) : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    String label = "Create Account";
    if (registrationMethod == 'phone' && !_codeSent) label = "Send OTP";
    if (registrationMethod == 'phone' && _codeSent) label = "Verify & Register";

    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7A002B), Color(0xFFAC1634), Color(0xFFE77291)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7A002B).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : _handleRegistration,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    height: 28, width: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: enabled,
        validator: validator,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
            labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          filled: true,
          fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF7A002B),
              width: 2.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
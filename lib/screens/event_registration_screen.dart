import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/registration_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class EventRegistrationScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventRegistrationScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final RegistrationService _registrationService = RegistrationService();
  bool isLoading = false;
  bool isRegistered = false;
  Map<String, dynamic>? registrationData;
  Map<String, dynamic>? userData;

  // Team Registration Fields
  final _teamNameController = TextEditingController();
  List<Map<String, String>> teamMembers = [];
  final _formKey = GlobalKey<FormState>();

  // Payment Fields
  bool _showPaymentStep = false;
  File? _paymentScreenshot;
  String? _paymentScreenshotUrl;
  bool _isUploadingScreenshot = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkRegistration();
    _addInitialMember();
  }

  void _addInitialMember() {
    setState(() {
      teamMembers.add({
        'name': '',
        'univ': '', // Track university selection
        'college': '',
        'email': '',
        'phone': '',
        'semester': '',
        'department': '',
      });
    });
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        userData = userDoc.data();
      });
    }
  }

  Future<void> _checkRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final registration = await FirebaseFirestore.instance
        .collection('event_registrations')
        .where('eventId', isEqualTo: widget.eventId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (registration.docs.isNotEmpty) {
      setState(() {
        isRegistered = true;
        registrationData = registration.docs.first.data();
        registrationData!['id'] = registration.docs.first.id;
      });
    }
  }

  Future<void> _registerForEvent() async {
    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User data not found")),
      );
      return;
    }

    // Intra-college restriction check
    final collegeType = widget.eventData['collegeType'] as String?;
    final userRole = (userData!['role'] ?? 'student').toString().toLowerCase().trim();
    
    if (userRole != 'admin' && collegeType == 'Intra College') {
      final hostingCollege = widget.eventData['hostingCollege'] as String?;
      final userCollege = userData!['collegeName'] as String?;
      
      if (hostingCollege != null && hostingCollege.isNotEmpty && userCollege != null && 
          hostingCollege.toLowerCase().trim() != userCollege.toLowerCase().trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("This event is restricted to students of $hostingCollege"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (widget.eventData['isTeamEvent'] == true) {
      if (!_formKey.currentState!.validate()) return;
      _formKey.currentState!.save();
    }

    if (widget.eventData['paidEvent'] == true && !_showPaymentStep) {
      setState(() {
        _showPaymentStep = true;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic>? teamData;
      if (widget.eventData['isTeamEvent'] == true) {
        teamData = {
          'teamName': _teamNameController.text.trim(),
          'members': teamMembers,
        };
      }

      final result = await _registrationService.registerForEvent(
        eventId: widget.eventId,
        eventData: widget.eventData,
        userData: userData!,
        teamData: teamData,
        paymentScreenshotUrl: _paymentScreenshotUrl,
      );

      setState(() {
        isRegistered = true;
        registrationData = result;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Successfully registered for event! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Event Registration"),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : isRegistered && registrationData != null
              ? _buildTicketView(context, isDark)
              : _showPaymentStep
                  ? _buildPaymentStep(context, isDark)
                  : _buildRegistrationForm(context, isDark),
    );
  }

  Widget _buildPaymentStep(BuildContext context, bool isDark) {
    final feeAmount = widget.eventData['feeAmount'];
    final paymentQrUrl = widget.eventData['paymentQrUrl'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Color(0xFF7A002B)),
          const SizedBox(height: 16),
          const Text(
            "Final Step: Payment",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Please pay the registration fee and upload the screenshot.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Amount to Pay",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹$feeAmount",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A002B),
                  ),
                ),
                const SizedBox(height: 24),
                
                if (paymentQrUrl != null) ...[
                  const Text("Scan this QR to Pay"),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      paymentQrUrl,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ] else
                  const Text("Contact organizer for payment details"),
                
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                
                const Text(
                  "Upload Payment Screenshot",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                InkWell(
                  onTap: _pickScreenshot,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _paymentScreenshotUrl != null ? Colors.green : Colors.grey.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _isUploadingScreenshot
                        ? const Center(child: CircularProgressIndicator())
                        : _paymentScreenshotUrl != null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 40),
                                  SizedBox(height: 8),
                                  Text("Screenshot Uploaded!", style: TextStyle(color: Colors.green)),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade500),
                                  const SizedBox(height: 8),
                                  Text("Tap to upload", style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _paymentScreenshotUrl != null ? _registerForEvent : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A002B),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "Submit Registration",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          
          TextButton(
            onPressed: () => setState(() => _showPaymentStep = false),
            child: const Text("Go Back"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _paymentScreenshot = File(image.path);
          _isUploadingScreenshot = true;
        });
        
        // Use StorageService to upload
        final storage = StorageService();
        final fileName = 'payment_screenshots/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await storage.uploadFile(
          file: _paymentScreenshot!,
          path: fileName,
          bucket: 'certificates',
        );

        setState(() {
          _paymentScreenshotUrl = url;
          _isUploadingScreenshot = false;
        });
      }
    } catch (e) {
      setState(() => _isUploadingScreenshot = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRegistrationForm(BuildContext context, bool isDark) {
    final allowsStudents = widget.eventData['audience']?['students'] == true;
    final allowsOutsiders = widget.eventData['audience']?['outsiders'] == true;
    final userRole = userData?['role'] ?? 'student';
    final isPaid = widget.eventData['paidEvent'] == true;
    final feeAmount = widget.eventData['feeAmount'];

    // Check if user can register
    if (userRole == 'student' && !allowsStudents) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                "Students not allowed",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "This event is not open for student registration",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (userRole == 'visitor' && !allowsOutsiders) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                "Visitors not allowed",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "This event is only for students",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final posterUrl = widget.eventData['posterUrl'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Banner
          if (posterUrl != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF7A002B),
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.white, size: 48),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ),

          // Event Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eventData['title'] ?? 'Event',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A002B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, color: Color(0xFF7A002B)),
                        const SizedBox(width: 8),
                        Text(
                          "Registration Fee: ₹${feeAmount ?? 0}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A002B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Free Event",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Team Form if applicable
          if (widget.eventData['isTeamEvent'] == true) ...[
            _buildTeamForm(isDark),
            const SizedBox(height: 24),
          ],

          // User Info Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF7A002B)),
                    const SizedBox(width: 8),
                    Text(
                      widget.eventData['isTeamEvent'] == true ? "Team Leader Details" : "Registration Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow("Name", userData?['name'] ?? 'N/A', isDark),
                if (userRole == 'student') ...[
                  _buildInfoRow("College", userData?['collegeName'] ?? 'N/A', isDark),
                  _buildInfoRow("Department", userData?['department'] ?? 'N/A', isDark),
                  _buildInfoRow("Semester", userData?['semester'] ?? 'N/A', isDark),
                ] else ...[
                  _buildInfoRow("Phone", userData?['phone'] ?? 'N/A', isDark),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Register Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A002B).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _registerForEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.eventData['isTeamEvent'] == true ? "Register Team" : "Register for Event",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTeamForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, color: Color(0xFF7A002B)),
                    const SizedBox(width: 8),
                    Text(
                      "Team Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teamNameController,
                  decoration: _inputDecoration("Team Name", Icons.group_work, isDark),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  validator: (v) => v == null || v.isEmpty ? "Team name required" : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Team Members",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                "${teamMembers.length} Members",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...teamMembers.asMap().entries.map((entry) {
            int idx = entry.key;
            return _buildMemberCard(idx, isDark);
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  teamMembers.add({
                    'name': '',
                    'univ': '',
                    'college': '',
                    'email': '',
                    'phone': '',
                    'semester': '',
                    'department': '',
                  });
                });
              },
              icon: const Icon(Icons.person_add),
              label: const Text("Add Member Details"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF7A002B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: const Color(0xFF7A002B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(int idx, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A002B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Member ${idx + 1}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7A002B)),
                ),
              ),
              if (idx > 0)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => teamMembers.removeAt(idx)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: _inputDecoration("Full Name", Icons.person_outline, isDark),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            onChanged: (v) => teamMembers[idx]['name'] = v,
            validator: (v) => v == null || v.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: teamMembers[idx]['univ'] == '' ? null : teamMembers[idx]['univ'],
            items: AppConstants.universityData.keys.map((String univ) {
              return DropdownMenuItem(
                value: univ,
                child: Text(
                  univ,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                teamMembers[idx]['univ'] = v ?? '';
                teamMembers[idx]['college'] = ''; // reset college
              });
            },
            decoration: _inputDecoration("University", Icons.school, isDark),
            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            isExpanded: true,
            validator: (v) => v == null || v.isEmpty ? "Required" : null,
          ),
          const SizedBox(height: 12),
          if (teamMembers[idx]['univ'] != '' && teamMembers[idx]['univ'] != 'Other')
            DropdownButtonFormField<String>(
              value: teamMembers[idx]['college'] == '' ? null : teamMembers[idx]['college'],
              items: AppConstants.universityData[teamMembers[idx]['univ']]!.map((String clg) {
                return DropdownMenuItem(
                  value: clg,
                  child: Text(
                    clg,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  teamMembers[idx]['college'] = v ?? '';
                });
              },
              decoration: _inputDecoration("College", Icons.business, isDark),
              dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              isExpanded: true,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
            )
          else
            TextFormField(
              decoration: _inputDecoration(
                  teamMembers[idx]['univ'] == 'Other' ? "Enter College Name" : "College Name",
                  Icons.school_outlined,
                  isDark),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              onChanged: (v) => teamMembers[idx]['college'] = v,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration("Email ID", Icons.alternate_email, isDark, dense: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => teamMembers[idx]['email'] = v,
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration("Phone", Icons.phone_android, isDark, dense: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => teamMembers[idx]['phone'] = v,
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration("Department", Icons.apartment, isDark, dense: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                  onChanged: (v) => teamMembers[idx]['department'] = v,
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration("Semester", Icons.school, isDark, dense: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                  onChanged: (v) => teamMembers[idx]['semester'] = v,
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark, {bool dense = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: dense ? 18 : 22),
      filled: true,
      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
      contentPadding: dense ? const EdgeInsets.symmetric(vertical: 10, horizontal: 12) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketView(BuildContext context, bool isDark) {
    final qrData = registrationData!['qrCodeData'] as String? ?? '';
    final posterUrl = widget.eventData['posterUrl'] as String?;
    final isTeamRegistration = registrationData!['isTeamRegistration'] == true;
    final teamData = registrationData!['teamData'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Ticket Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A002B), Color(0xFFAC1634)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A002B).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                if (posterUrl != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusBadge(registrationData!['status'] ?? 'pending'),
                const SizedBox(height: 16),
                Text(
                  "Ticket #${registrationData!['ticketNumber']}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.eventData['title'] ?? 'Event',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          if (isTeamRegistration && teamData != null)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Team Info: ${teamData['teamName']}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Divider(height: 24),
                  ...(teamData['members'] as List).map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              member['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            member['role'] ?? 'Member',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                  )),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ticket Details",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow("Name", userData?['name'] ?? 'N/A', isDark),
                const Divider(height: 32),
                _buildInfoRow("Date", widget.eventData['date'] != null ? (widget.eventData['date'] as Timestamp).toDate().toString().split(' ')[0] : 'TBA', isDark),
                _buildInfoRow("Venue", widget.eventData['location'] ?? 'TBA', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status.toLowerCase()) {
      case 'approved':
      case 'confirmed':
        color = Colors.green;
        icon = Icons.check_circle;
        text = "APPROVED";
        break;
      case 'declined':
        color = Colors.red;
        icon = Icons.cancel;
        text = "DECLINED";
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.timer_outlined;
        text = "PENDING VERIFICATION";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

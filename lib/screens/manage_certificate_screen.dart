import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/event_service.dart';
import '../services/certificate_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCertificateScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const ManageCertificateScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<ManageCertificateScreen> createState() => _ManageCertificateScreenState();
}

class _ManageCertificateScreenState extends State<ManageCertificateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _certificateService = CertificateService();
  final _eventService = EventService();

  late String _certificateTitle;
  late String _signatureName;
  late String _signatureTitle;
  
  bool _isGenerating = false;
  bool _isSending = false;
  bool _certificatesGenerated = false;
  bool _certificatesSent = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkStatus();
  }

  void _loadSettings() {
    final settings = widget.eventData['certificateSettings'] as Map<String, dynamic>?;
    _certificateTitle = settings?['title'] ?? (widget.eventData['certificateType'] ?? 'PARTICIPATION').toString().toUpperCase();
    _signatureName = settings?['signatureName'] ?? widget.eventData['organizerName'] ?? 'Event Organizer';
    _signatureTitle = settings?['signatureTitle'] ?? 'Organizer';
  }

  Future<void> _checkStatus() async {
    final generated = await _certificateService.areCertificatesGenerated(widget.eventId);
    final published = await _certificateService.areCertificatesPublished(widget.eventId);
    
    if (mounted) {
      setState(() {
        _certificatesGenerated = generated;
        _certificatesSent = published;
      });
    }
  }

  Future<Uint8List> _generatePreview() async {
    // Extract template settings if available
    final templateImageUrl = widget.eventData['certificateTemplateUrl'] as String? ?? 
                             (widget.eventData['certificateSettings']?['templateImageUrl'] as String?);
                             
    final rawFields = (widget.eventData['certificateFields'] as List?) ?? 
                      (widget.eventData['certificateSettings']?['templateFields'] as List?);
    
    final templateFields = rawFields?.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Dummy data for preview
    return _certificateService.generateCertificatePDF(
      participantName: 'John Doe',
      eventName: widget.eventData['title'] ?? 'Event Name',
      eventDate: '01 January 2024',
      organizerName: _signatureName, 
      certificateType: _certificateTitle,
      certificateSettings: {
        'title': _certificateTitle,
        'signatureName': _signatureName,
        'signatureTitle': _signatureTitle,
      },
      templateImageUrl: templateImageUrl,
      templateFields: templateFields,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Manage Certificates'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Preview Section
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: PdfPreview(
                build: (format) => _generatePreview(),
                useActions: false, // Disable print/share buttons for preview
                scrollViewDecoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.grey.shade200,
                ),
                loadingWidget: const Center(child: CircularProgressIndicator()),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Certificate Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Certificate Title
                    TextFormField(
                      initialValue: _certificateTitle,
                      decoration: _inputDecoration("Certificate Title", Icons.title, isDark),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      onChanged: (v) => setState(() => _certificateTitle = v),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Signature Name
                    TextFormField(
                      initialValue: _signatureName,
                      decoration: _inputDecoration("Signatory Name", Icons.draw, isDark),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      onChanged: (v) => setState(() => _signatureName = v),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Signature Title
                    TextFormField(
                      initialValue: _signatureTitle,
                      decoration: _inputDecoration("Signatory Title", Icons.badge, isDark),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      onChanged: (v) => setState(() => _signatureTitle = v),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),

                    const SizedBox(height: 30),

                    // Action Buttons
                    if (_certificatesSent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              "Certificates Sent to All Participants",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_certificatesGenerated)
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Certificates generated but not sent yet. Review the preview above.",
                                    style: TextStyle(color: Colors.orangeAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildActionButton(
                            label: "Send Certificates",
                            icon: Icons.send,
                            color: const Color(0xFF00D2D3),
                            isLoading: _isSending,
                            onPressed: _sendCertificates,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildActionButton(
                            label: "Save Settings & Generate",
                            icon: Icons.workspace_premium,
                            color: const Color(0xFF7A002B),
                            isLoading: _isGenerating,
                            onPressed: _saveAndGenerate,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Participants will NOT be notified yet.",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          isLoading ? "Processing..." : label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndGenerate() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isGenerating = true);
    
    try {
      // 1. Fetch LATEST event data to ensure we have the correct template
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final latestEventData = eventDoc.data() as Map<String, dynamic>;

      // 2. Save settings
      final settings = {
        'title': _certificateTitle,
        'signatureName': _signatureName,
        'signatureTitle': _signatureTitle,
      };
      
      await _eventService.updateEvent(widget.eventId, {
        'certificateSettings': settings,
      });

      // 3. Generate certificates using LATEST event data
      await _certificateService.generateCertificatesForEvent(
        eventId: widget.eventId,
        eventData: latestEventData,
        certificateSettings: settings,
      );

      // 3. Update status
      setState(() {
        _certificatesGenerated = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificates generated successfully! Click Send to distribute.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _sendCertificates() async {
    setState(() => _isSending = true);
    
    try {
      await _certificateService.publishCertificates(widget.eventId);
      
      setState(() {
        _certificatesSent = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificates sent to all participants!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending certificates: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

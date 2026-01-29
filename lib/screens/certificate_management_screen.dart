import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/certificate_service.dart';

class CertificateManagementScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const CertificateManagementScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<CertificateManagementScreen> createState() => _CertificateManagementScreenState();
}

class _CertificateManagementScreenState extends State<CertificateManagementScreen> {
  final CertificateService _certificateService = CertificateService();

  // Certificate template data
  String selectedTemplate = 'default';
  String certificateTitle = 'Certificate of Participation';
  String organizerName = '';
  String customMessage = '';
  bool includeCollegeName = true;
  bool includeDepartment = true;
  bool includeSemester = true;

  // Available templates
  final List<Map<String, dynamic>> templates = [
    {
      'id': 'default',
      'name': 'Classic Gold',
      'description': 'Traditional gold-bordered certificate',
      'preview': 'assets/images/certificate_template_1.png',
    },
    {
      'id': 'modern',
      'name': 'Modern Blue',
      'description': 'Contemporary blue-themed design',
      'preview': 'assets/images/certificate_template_2.png',
    },
    {
      'id': 'minimal',
      'name': 'Minimalist',
      'description': 'Clean and simple design',
      'preview': 'assets/images/certificate_template_3.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingTemplate();
  }

  Future<void> _loadExistingTemplate() async {
    // Load existing certificate template settings from event data
    setState(() {
      selectedTemplate = widget.eventData['certificateTemplate'] ?? 'default';
      certificateTitle = widget.eventData['certificateTitle'] ?? 'Certificate of Participation';
      organizerName = widget.eventData['organizerName'] ?? '';
      customMessage = widget.eventData['certificateMessage'] ?? '';
      includeCollegeName = widget.eventData['includeCollegeName'] ?? true;
      includeDepartment = widget.eventData['includeDepartment'] ?? true;
      includeSemester = widget.eventData['includeSemester'] ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Certificate Management'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template Selection
            _buildSection(
              'Certificate Template',
              Icons.palette,
              _buildTemplateSelection(),
            ),

            const SizedBox(height: 24),

            // Certificate Content
            _buildSection(
              'Certificate Content',
              Icons.edit,
              _buildContentEditor(),
            ),

            const SizedBox(height: 24),

            // Preview Section
            _buildSection(
              'Preview',
              Icons.visibility,
              _buildPreview(),
            ),

            const SizedBox(height: 24),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateCertificates,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Generate Certificates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF6C5CE7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: templates.map((template) {
        final isSelected = selectedTemplate == template['id'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => setState(() => selectedTemplate = template['id']),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          template['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF6C5CE7),
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContentEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Certificate Title
        TextFormField(
          initialValue: certificateTitle,
          decoration: InputDecoration(
            labelText: 'Certificate Title',
            hintText: 'e.g., Certificate of Participation',
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          onChanged: (value) => certificateTitle = value,
        ),

        const SizedBox(height: 16),

        // Organizer Name
        TextFormField(
          initialValue: organizerName,
          decoration: InputDecoration(
            labelText: 'Organizer Name',
            hintText: 'Name to appear as certificate issuer',
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          onChanged: (value) => organizerName = value,
        ),

        const SizedBox(height: 16),

        // Custom Message
        TextFormField(
          initialValue: customMessage,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Custom Message (Optional)',
            hintText: 'Additional message to include on certificate',
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          onChanged: (value) => customMessage = value,
        ),

        const SizedBox(height: 16),

        // Include Options
        const Text(
          'Include in Certificate:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        CheckboxListTile(
          title: const Text('College Name'),
          value: includeCollegeName,
          onChanged: (value) => setState(() => includeCollegeName = value ?? true),
          activeColor: const Color(0xFF6C5CE7),
        ),

        CheckboxListTile(
          title: const Text('Department'),
          value: includeDepartment,
          onChanged: (value) => setState(() => includeDepartment = value ?? true),
          activeColor: const Color(0xFF6C5CE7),
        ),

        CheckboxListTile(
          title: const Text('Semester'),
          value: includeSemester,
          onChanged: (value) => setState(() => includeSemester = value ?? true),
          activeColor: const Color(0xFF6C5CE7),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Certificate Preview',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Preview will be available after saving template',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    try {
      // Update event with certificate template settings
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'certificateTemplate': selectedTemplate,
        'certificateTitle': certificateTitle,
        'organizerName': organizerName,
        'certificateMessage': customMessage,
        'includeCollegeName': includeCollegeName,
        'includeDepartment': includeDepartment,
        'includeSemester': includeSemester,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate template saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateCertificates() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // First save the template
      await _saveTemplate();

      // Update event data with current settings
      final updatedEventData = {
        ...widget.eventData,
        'certificateTemplate': selectedTemplate,
        'certificateTitle': certificateTitle,
        'organizerName': organizerName,
        'certificateMessage': customMessage,
        'includeCollegeName': includeCollegeName,
        'includeDepartment': includeDepartment,
        'includeSemester': includeSemester,
      };

      // Generate certificates for all attendees
      await _certificateService.generateCertificatesForEvent(
        eventId: widget.eventId,
        eventData: updatedEventData,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificates generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to attendance report
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating certificates: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
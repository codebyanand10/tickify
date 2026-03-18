import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart';
import '../services/certificate_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CertificateTemplateEditorScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final String? eventId; // null if creating new event

  const CertificateTemplateEditorScreen({
    super.key,
    required this.eventData,
    this.eventId,
  });

  @override
  State<CertificateTemplateEditorScreen> createState() => _CertificateTemplateEditorScreenState();
}

class _CertificateTemplateEditorScreenState extends State<CertificateTemplateEditorScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _templateImage;
  String? _templateImageUrl;
  bool _isUploading = false;
  
  // Field placements on the template
  List<CertificateField> _fields = [];
  CertificateField? _selectedField;
  
  // Image properties for relative positioning
  double _imageAspectRatio = 1.414; // Default landscape A4
  GlobalKey _imageKey = GlobalKey();
  
  // Available registration data fields
  final List<Map<String, dynamic>> _availableFields = [
    {'key': 'participantName', 'label': 'Participant Name', 'icon': Icons.person, 'sample': 'John Doe'},
    {'key': 'eventName', 'label': 'Event Name', 'icon': Icons.event, 'sample': 'Tech Summit 2026'},
    {'key': 'eventDate', 'label': 'Event Date', 'icon': Icons.calendar_today, 'sample': 'Jan 29, 2026'},
    {'key': 'department', 'label': 'Department', 'icon': Icons.school, 'sample': 'Computer Science'},
    {'key': 'semester', 'label': 'Semester', 'icon': Icons.numbers, 'sample': 'S6'},
    {'key': 'collegeName', 'label': 'College Name', 'icon': Icons.business, 'sample': 'Engineering College'},
    {'key': 'organizerName', 'label': 'Organizer Name', 'icon': Icons.person_outline, 'sample': 'Dr. Anamika'},
    {'key': 'certificateId', 'label': 'Certificate ID', 'icon': Icons.qr_code, 'sample': 'CERT-123456'},
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingTemplate();
  }

  Future<void> _loadExistingTemplate() async {
    if (widget.eventId != null) {
      try {
        final eventDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .get();
        
        if (eventDoc.exists) {
          final data = eventDoc.data();
          if (data?['certificateTemplateUrl'] != null) {
            setState(() {
              _templateImageUrl = data!['certificateTemplateUrl'];
            });
            _loadImageDimensions(_templateImageUrl!);
          }
          if (data?['certificateFields'] != null) {
            final fieldsData = data!['certificateFields'] as List;
            setState(() {
              _fields = fieldsData.map((f) => CertificateField.fromMap(f)).toList();
            });
          }
        }
      } catch (e) {
        print('Error loading template: $e');
      }
    }
  }

  Future<void> _loadImageDimensions(String url) async {
    // Deprecated: We now force A4 Landscape ratio to match PDF output
    // keeping method to avoid breaking compile if called, but it does nothing
  }
  
  Future<void> _loadFileDimensions(File file) async {
    // Deprecated: We now force A4 Landscape ratio to match PDF output
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        final file = File(image.path);
        setState(() {
          _templateImage = file;
          _templateImageUrl = null; // Clear URL when new image is selected
        });
        await _loadFileDimensions(file);
        // Auto upload? Or wait for save?
        // Let's auto upload for smoother UX if they save later
        if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image selected. Click Upload/Save to finalize.')),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadTemplate() async {
    if (_templateImage == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'certificate_templates/$fileName';
      
      final storageService = StorageService();
      final downloadUrl = await storageService.uploadFile(
        file: _templateImage!,
        path: filePath,
        bucket: 'certificates',
      );

      setState(() {
        _templateImageUrl = downloadUrl;
        _templateImage = null;
        _isUploading = false;
      });

      // Update event data immediately if edit mode
      if (widget.eventId != null) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
          'certificateTemplateUrl': downloadUrl,
        });
      } else {
        widget.eventData['certificateTemplateUrl'] = downloadUrl;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addField(String key) {
    setState(() {
      // Default position: Center
      _fields.add(CertificateField(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        x: 0.5, // Center
        y: 0.5, // Center
        fieldKey: key,
        fontSize: 24, // Relative PDF font size (approximated)
        fontColor: Colors.black,
        fontWeight: FontWeight.normal,
      ));
      _selectedField = _fields.last;
    });
  }

  void _updateField(CertificateField field) {
    setState(() {
      final index = _fields.indexWhere((f) => f.id == field.id);
      if (index != -1) {
        _fields[index] = field;
        _selectedField = field;
      }
    });
  }

  void _deleteField(String fieldId) {
    setState(() {
      _fields.removeWhere((f) => f.id == fieldId);
      if (_selectedField?.id == fieldId) {
        _selectedField = null;
      }
    });
  }

  Future<void> _saveTemplate() async {
    // If local file exists but not uploaded, upload it first
    if (_templateImage != null && _templateImageUrl == null) {
      await _uploadTemplate();
    }
    
    if (_templateImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select and upload a template image first')),
      );
      return;
    }

    final fieldsData = _fields.map((f) => f.toMap()).toList();

    // Dialog to choose Save Type
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Design"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Apply to Current Event"),
              subtitle: const Text("Use this design only for this event"),
              onTap: () async {
                 Navigator.pop(context);
                 await _saveToEvent(fieldsData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add),
              title: const Text("Save as New Template"),
              subtitle: const Text("Save to your library for future use"),
              onTap: () async {
                Navigator.pop(context);
                final name = await _askTemplateName();
                if (name != null && name.isNotEmpty) {
                    // Save to Library
                   final certService = CertificateService(); 
                   
                   try {
                     await certService.saveSeriesTemplate(
                        name: name,
                        imageUrl: _templateImageUrl!,
                        fields: fieldsData,
                     );
                     
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved to Template Library!'), backgroundColor: Colors.green),
                        );
                     }
                   } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving template: $e'), backgroundColor: Colors.red),
                        );
                      }
                   }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askTemplateName() async {
      String name = '';
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Template Name"),
          content: TextField(
            onChanged: (v) => name = v,
            decoration: const InputDecoration(hintText: "e.g. My Gold Design"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, name),
              child: const Text("Save"),
            ),
          ],
        ),
      );
  }

  Future<void> _saveToEvent(List<Map<String, dynamic>> fieldsData) async {
    try {
      if (widget.eventId != null) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
          'certificateTemplateUrl': _templateImageUrl,
          'certificateFields': fieldsData,
        });
      } else {
        widget.eventData['certificateTemplateUrl'] = _templateImageUrl;
        widget.eventData['certificateFields'] = fieldsData;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved to Event!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showPreview() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Uint8List? imgBytes;
      if (_templateImage != null) {
        imgBytes = await _templateImage!.readAsBytes();
      }

      final service = CertificateService();
      final pdfBytes = await service.generateCertificatePDF(
        participantName: "JOHN DOE",
        eventName: widget.eventData['title'] ?? "TECH SUMMIT 2026",
        eventDate: "March 15, 2026",
        organizerName: "Event Organizer",
        department: "Computer Science",
        semester: "6",
        collegeName: "University College of Engineering",
        templateFields: _fields.map((f) => f.toMap()).toList(),
        templateImageUrl: _templateImageUrl, // Fallback if image not local
        templateImageBytes: imgBytes, // Use local bytes if available
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => 
          Scaffold(
            appBar: AppBar(title: const Text("Certificate Preview")),
            body: PdfPreview(
              build: (format) => pdfBytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowPrinting: true,
              allowSharing: true,
            ),
          )
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating preview: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Design Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showPreview,
            icon: const Icon(Icons.remove_red_eye),
            tooltip: "Preview PDF",
          ),
          TextButton.icon(
            onPressed: _saveTemplate,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar / Top Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(_templateImage == null && _templateImageUrl == null 
                        ? 'Upload Background' 
                        : 'Change Background'),
                  ),
                ),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          
          // Canvas Area
          Expanded(
            child: Center(
              child: (_templateImage == null && _templateImageUrl == null)
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate display size to fit within constraints while maintaining aspect ratio
                        double displayWidth = constraints.maxWidth;
                        double displayHeight = displayWidth / _imageAspectRatio;
                        
                        if (displayHeight > constraints.maxHeight) {
                          displayHeight = constraints.maxHeight;
                          displayWidth = displayHeight * _imageAspectRatio;
                        }
                        
                        return Container(
                          width: displayWidth,
                          height: displayHeight,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 1. Background Image
                              Positioned.fill(
                                child: _templateImage != null
                                    ? Image.file(_templateImage!, fit: BoxFit.fill)
                                    : Image.network(_templateImageUrl!, fit: BoxFit.fill),
                              ),
                              
                              // 2. Fields
                              ..._fields.map((field) => _buildDraggableField(
                                field, 
                                displayWidth, 
                                displayHeight
                              )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Field Controls (Bottom Panel)
          _buildBottomPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.style_outlined, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          'Upload a certificate background\nto start designing',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Template Image'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        )
      ],
    );
  }

  Widget _buildDraggableField(CertificateField field, double containerWidth, double containerHeight) {
    final isSelected = _selectedField?.id == field.id;
    final sampleText = _availableFields.firstWhere(
      (f) => f['key'] == field.fieldKey, 
      orElse: () => {'sample': field.fieldKey}
    )['sample'];

    // Alignment (-1.0 to 1.0)
    final alignX = (field.x * 2) - 1;
    final alignY = (field.y * 2) - 1;

    // Approximate scaling Factor for font rendering on screen vs PDF
    // PDF A4 Landscape layout width is ~842 points (29.7cm)
    final visualFontSize = field.fontSize * (containerWidth / 842.0);

    return Align(
      alignment: Alignment(alignX, alignY),
      child: GestureDetector(
        onTap: () => setState(() => _selectedField = field),
        onPanUpdate: (details) {
          setState(() {
            // Update X and Y in percentage (0.0 - 1.0)
            double newX = field.x + (details.delta.dx / containerWidth);
            double newY = field.y + (details.delta.dy / containerHeight);
            
            // Clamp to keep inside
            newX = newX.clamp(0.0, 1.0);
            newY = newY.clamp(0.0, 1.0);
            
            _updateField(field.copyWith(x: newX, y: newY));
            _selectedField = field; // Auto select on drag
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: isSelected 
                ? Border.all(color: Colors.blueAccent, width: 2) 
                : Border.all(color: Colors.transparent, width: 2), // Invisible border for touch area
            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          ),
          child: Text(
            sampleText,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: visualFontSize < 8 ? 8 : visualFontSize, // Min size for readability
              fontWeight: field.fontWeight,
              color: field.fontColor,
              fontFamily: 'Roboto', 
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    if (_selectedField != null) {
      return _buildPropertyEditor(isDark);
    }
    
    // Field Selector
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        itemCount: _availableFields.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = _availableFields[index];
          return GestureDetector(
            onTap: () => _addField(item['key']),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'], color: const Color(0xFF6C5CE7)),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'], 
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87
                  )
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyEditor(bool isDark) {
    final field = _selectedField!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0,-5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Edit ${_availableFields.firstWhere((f) => f['key'] == field.fieldKey)['label']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _deleteField(field.id),
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Field',
              ),
              IconButton(
                onPressed: () => setState(() => _selectedField = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Font Size Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Size: ${field.fontSize.toInt()}", style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: field.fontSize,
                      min: 10, max: 80,
                      onChanged: (v) => _updateField(field.copyWith(fontSize: v)),
                    ),
                  ],
                ),
              ),
              // Bold Toggle
              IconButton(
                onPressed: () => _updateField(field.copyWith(
                  fontWeight: field.fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold
                )),
                icon: Icon(Icons.format_bold, 
                   color: field.fontWeight == FontWeight.bold ? Colors.blue : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Colors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                 Colors.black, Colors.white, Colors.grey, Colors.blue, Colors.red, Colors.green, 
                 const Color(0xFFD4AF37) // Gold
              ].map((c) {
                 return GestureDetector(
                   onTap: () => _updateField(field.copyWith(fontColor: c)),
                   child: Container(
                     margin: const EdgeInsets.only(right: 12),
                     width: 32, height: 32,
                     decoration: BoxDecoration(
                       color: c,
                       shape: BoxShape.circle,
                       border: Border.all(
                         color: Colors.grey.shade400,
                         width: field.fontColor == c ? 3 : 1
                       ),
                     ),
                     child: field.fontColor == c 
                       ? Center(child: Icon(Icons.check, size: 16, 
                           color: c == Colors.white ? Colors.black : Colors.white))
                       : null,
                   ),
                 );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}

// Updated Model with Relative Coordinates support
class CertificateField {
  final String id;
  final double x; // Percentage 0.0 - 1.0 from Left
  final double y; // Percentage 0.0 - 1.0 from Top
  final String fieldKey;
  final double fontSize;
  final Color fontColor;
  final FontWeight fontWeight;

  CertificateField({
    required this.id,
    required this.x,
    required this.y,
    required this.fieldKey,
    required this.fontSize,
    required this.fontColor,
    this.fontWeight = FontWeight.normal,
  });

  CertificateField copyWith({
    String? id,
    double? x,
    double? y,
    String? fieldKey,
    double? fontSize,
    Color? fontColor,
    FontWeight? fontWeight,
  }) {
    return CertificateField(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      fieldKey: fieldKey ?? this.fieldKey,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'fieldKey': fieldKey,
      'fontSize': fontSize,
      'fontWeight': fontWeight == FontWeight.bold ? 'bold' : 'normal',
      'fontColor': {
        'r': fontColor.red,
        'g': fontColor.green,
        'b': fontColor.blue,
        'a': fontColor.alpha,
      },
    };
  }

  factory CertificateField.fromMap(Map<String, dynamic> map) {
    final colorMap = map['fontColor'] as Map<String, dynamic>;
    return CertificateField(
      id: map['id'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      fieldKey: map['fieldKey'] as String,
      fontSize: (map['fontSize'] as num).toDouble(),
      fontWeight: map['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal,
      fontColor: Color.fromARGB(
        colorMap['a'] as int,
        colorMap['r'] as int,
        colorMap['g'] as int,
        colorMap['b'] as int,
      ),
    );
  }
}

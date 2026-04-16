import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/event_service.dart';
import '../services/certificate_service.dart';
import '../services/event_service.dart';
import '../services/certificate_service.dart';
import 'certificate_template_editor_screen.dart';
import 'template_selection_screen.dart';
import '../utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EditEventScreen({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();

  // Basic details
  late String title;
  late String category;
  late String description;
  late String location;

  DateTime? eventDate;
  TimeOfDay? eventTime;

  // Toggles
  bool limitedSeats = false;
  bool paidEvent = false;
  bool certificationEvent = false;
  bool whatsappEnabled = false;
  bool isTeamEvent = false;

  int? seatCount;
  double? feeAmount;
  String whatsappLink = '';

  String collegeType = 'Intra College';
  String? hostingUniversity;
  String? hostingCollege;
  bool isOtherUniversity = false;
  bool isOtherCollege = false;
  final _otherUniversityController = TextEditingController();
  final _otherCollegeController = TextEditingController();

  // Audience
  bool students = true;
  bool outsiders = false;
  bool staff = false;

  List<Map<String, String>> coordinators = [
    {'name': '', 'phone': ''}
  ];

  String? _certificateTemplateUrl;
  List<dynamic>? _certificateFields;

  // Category keys (lowercase, singular) - these match Firestore values
  final categories = [
    'workshop',
    'ideathon',
    'hackathon',
    'cultural',
    'seminar',
    'tournament',
  ];

  // Display labels for categories
  static const Map<String, String> categoryLabels = {
    'workshop': 'Workshop',
    'ideathon': 'Ideathon',
    'hackathon': 'Hackathon',
    'cultural': 'Cultural Event',
    'seminar': 'Seminar',
    'tournament': 'Tournament',
  };

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  void _loadEventData() {
    final data = widget.eventData;
    
    title = data['title'] ?? '';
    category = (data['category'] ?? 'workshop').toString().toLowerCase();
    description = data['description'] ?? '';
    location = data['location'] ?? '';

    // Parse date
    if (data['date'] != null) {
      final timestamp = data['date'] as Timestamp?;
      if (timestamp != null) {
        eventDate = timestamp.toDate();
      }
    }

    // Parse time
    if (data['time'] != null) {
      final timeStr = data['time'] as String;
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        eventTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    limitedSeats = data['limitedSeats'] ?? false;
    seatCount = data['seatCount'] as int?;
    paidEvent = data['paidEvent'] ?? false;
    feeAmount = (data['feeAmount'] as num?)?.toDouble();
    certificationEvent = data['certification'] ?? false;
    isTeamEvent = data['isTeamEvent'] ?? false;
    collegeType = data['collegeType'] ?? 'Intra College';
    hostingUniversity = data['hostingUniversity'];
    hostingCollege = data['hostingCollege'];

    // Check if hosted in an "other" institution
    if (hostingUniversity != null && hostingUniversity != 'Other' && !AppConstants.universityData.containsKey(hostingUniversity)) {
      isOtherUniversity = true;
      _otherUniversityController.text = hostingUniversity!;
      hostingUniversity = 'Other';
    }

    if (hostingCollege != null && hostingCollege != 'Other' && hostingUniversity != null && 
        AppConstants.universityData[hostingUniversity] != null && 
        !AppConstants.universityData[hostingUniversity]!.contains(hostingCollege)) {
      isOtherCollege = true;
      _otherCollegeController.text = hostingCollege!;
      hostingCollege = 'Other';
    }

    // Parse audience
    final audience = data['audience'] as Map<String, dynamic>?;
    if (audience != null) {
      students = audience['students'] ?? false;
      outsiders = audience['outsiders'] ?? false;
      staff = audience['staff'] ?? false;
    }

    // Parse coordinators
    final coords = data['coordinators'] as List?;
    if (coords != null && coords.isNotEmpty) {
      coordinators = coords.map((c) {
        final map = c as Map<String, dynamic>;
        return {
          'name': map['name']?.toString() ?? '',
          'phone': map['phone']?.toString() ?? '',
        };
      }).toList();
    } else {
      coordinators = [{'name': '', 'phone': ''}];
    }

    // Parse WhatsApp
    final whatsapp = data['whatsappLink'];
    if (whatsapp != null && whatsapp.toString().isNotEmpty) {
      whatsappEnabled = true;
      whatsappLink = whatsapp.toString();
    }

    _certificateTemplateUrl = data['certificateTemplateUrl'];
    _certificateFields = data['certificateFields'];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text(
          "Edit Event",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Edit Your Event",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Update event details below",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1. Event title
              buildTextField(
                "Event Title",
                initialValue: title,
                icon: Icons.title,
                onSaved: (v) => title = v,
              ),

              // 2. Category
              buildDropdown(
                "Category",
                categories,
                category,
                (v) => setState(() => category = v!),
                icon: Icons.category,
              ),

              // 3. Description
              buildTextField(
                "Description",
                initialValue: description,
                maxLines: 4,
                icon: Icons.description,
                onSaved: (v) => description = v,
              ),

              // 4. Date, Time, Location
              buildSection("Date & Location", icon: Icons.calendar_today),
              buildDatePicker(),
              buildTimePicker(),
              buildTextField(
                "Event Location",
                initialValue: location,
                icon: Icons.location_on,
                onSaved: (v) => location = v,
              ),

              // 6. Limited seats
              buildSwitch(
                "Limited Seats",
                limitedSeats,
                Icons.event_seat,
                (v) => setState(() => limitedSeats = v),
              ),
              if (limitedSeats)
                buildTextField(
                  "Seat Capacity",
                  initialValue: seatCount?.toString() ?? '',
                  icon: Icons.people,
                  isNumber: true,
                  onSaved: (v) => seatCount = v.isNotEmpty ? int.parse(v) : null,
                ),

               // 7. Institution Details
              buildSection("Hosting Institution", icon: Icons.school),
              buildDropdown(
                "Participation Scope",
                ['Intra College', 'Inter College'],
                collegeType,
                (v) => setState(() => collegeType = v!),
                icon: Icons.public,
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: hostingUniversity,
                items: AppConstants.universityData.keys.map((String univ) {
                  return DropdownMenuItem(
                    value: univ,
                    child: Text(univ, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    hostingUniversity = v;
                    hostingCollege = null;
                    isOtherUniversity = v == 'Other';
                    isOtherCollege = false;
                  });
                },
                decoration: _inputDecoration("Hosting University", Icons.account_balance, isDark),
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                validator: (v) => v == null ? "Required" : null,
              ),
              const SizedBox(height: 16),
              if (isOtherUniversity)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _otherUniversityController,
                    decoration: _inputDecoration("Other University Name", Icons.account_balance_outlined, isDark),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    validator: (v) => (isOtherUniversity && (v == null || v.isEmpty)) ? "Required" : null,
                  ),
                ),

              if (hostingUniversity != null && !isOtherUniversity)
                DropdownButtonFormField<String>(
                  value: hostingCollege,
                  items: AppConstants.universityData[hostingUniversity!]!.map((String clg) {
                    return DropdownMenuItem(
                      value: clg,
                      child: Text(clg, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      hostingCollege = v;
                      isOtherCollege = v == 'Other';
                    });
                  },
                  decoration: _inputDecoration("Hosting College", Icons.business, isDark),
                  dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  validator: (v) => v == null ? "Required" : null,
                ),
              
              if (isOtherCollege || (hostingUniversity == 'Other'))
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: TextFormField(
                    controller: _otherCollegeController,
                    decoration: _inputDecoration("College Name", Icons.business_outlined, isDark),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                  ),
                ),

              // 8. Audience
              buildSection("Audience", icon: Icons.people_outline),
              buildCheckbox("Students", students, Icons.school,
                  (v) => setState(() => students = v!)),
              buildCheckbox("Outsiders", outsiders, Icons.person_add,
                  (v) => setState(() => outsiders = v!)),
              buildCheckbox("Staff", staff, Icons.badge,
                  (v) => setState(() => staff = v!)),

              // 10. Registration fee
              buildSwitch(
                "Paid Event",
                paidEvent,
                Icons.payments,
                (v) => setState(() => paidEvent = v),
              ),
              if (paidEvent)
                buildTextField(
                  "Registration Fee (₹)",
                  initialValue: feeAmount?.toString() ?? '',
                  icon: Icons.currency_rupee,
                  isNumber: true,
                  onSaved: (v) => feeAmount = v.isNotEmpty ? double.parse(v) : null,
                ),

              // 11. Certification
              buildSwitch(
                "Certification Event",
                certificationEvent,
                Icons.verified,
                (v) => setState(() => certificationEvent = v),
              ),

              // 11.5 Team Event
              buildSwitch(
                "Team Event",
                isTeamEvent,
                Icons.group,
                (v) => setState(() => isTeamEvent = v),
              ),

              // 12. Coordinators
              buildSection("Event Coordinators", icon: Icons.contacts),
              ...coordinators.asMap().entries.map((entry) {
                int i = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: coordinators[i]['name'],
                          decoration: InputDecoration(
                            labelText: "Name",
                            prefixIcon: const Icon(Icons.person),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onSaved: (v) => coordinators[i]['name'] = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: coordinators[i]['phone'],
                          decoration: InputDecoration(
                            labelText: "Phone",
                            prefixIcon: const Icon(Icons.phone),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          keyboardType: TextInputType.phone,
                          onSaved: (v) => coordinators[i]['phone'] = v ?? '',
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      coordinators.add({'name': '', 'phone': ''});
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Coordinator"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2D3),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              // 13. WhatsApp link
              buildSwitch(
                "WhatsApp Group",
                whatsappEnabled,
                Icons.chat,
                (v) => setState(() => whatsappEnabled = v),
              ),
              if (whatsappEnabled)
                buildTextField(
                  "WhatsApp Link",
                  initialValue: whatsappLink,
                  icon: Icons.link,
                  onSaved: (v) => whatsappLink = v,
                ),

              const SizedBox(height: 24),

              // 14. Certificate Management (Customization)
              if (certificationEvent) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.workspace_premium, color: const Color(0xFFD4AF37), size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            "Certificate Template",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => CertificateTemplateEditorScreen(
                                      eventData: widget.eventData,
                                      eventId: widget.eventId,
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh data after editor closes
                                  FirebaseFirestore.instance
                                      .collection('events')
                                      .doc(widget.eventId)
                                      .get()
                                      .then((doc) {
                                    if (doc.exists) {
                                      setState(() {
                                        _certificateTemplateUrl = doc.data()?['certificateTemplateUrl'];
                                        _certificateFields = doc.data()?['certificateFields'];
                                      });
                                    }
                                  });
                                });
                              },
                              icon: const Icon(Icons.design_services),
                              label: const Text("Design New"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD4AF37),
                                side: const BorderSide(color: Color(0xFFD4AF37)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (context) => TemplateSelectionScreen(
                                      onTemplateSelected: (template) async {
                                          if (!mounted) return;
                                          final choice = await showDialog<String>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text("Selected Template"),
                                              content: const Text("Do you want to edit this design or use it as is?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, 'use'),
                                                  child: const Text("Use As Is"),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, 'edit'), 
                                                  child: const Text("Edit"),
                                                ),
                                              ],
                                            )
                                          );
                                          if (!mounted || choice == null) return;
                                          if (choice == 'edit') {
                                            await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
                                              'certificateTemplateUrl': template['imageUrl'],
                                              'certificateFields': template['fields'],
                                            });
                                            setState(() {
                                              _certificateTemplateUrl = template['imageUrl'];
                                              _certificateFields = template['fields'];
                                            });
                                            if (!mounted) return;
                                            Navigator.of(context, rootNavigator: true).push(
                                              MaterialPageRoute(
                                                builder: (context) => CertificateTemplateEditorScreen(
                                                  eventData: widget.eventData,
                                                  eventId: widget.eventId,
                                                ),
                                              ),
                                            );
                                          } else if (choice == 'use') {
                                            await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
                                              'certificateTemplateUrl': template['imageUrl'],
                                              'certificateFields': template['fields'],
                                            });
                                            setState(() {
                                              _certificateTemplateUrl = template['imageUrl'];
                                              _certificateFields = template['fields'];
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Template applied!"), backgroundColor: Colors.green)
                                            );
                                          }
                                      },
                                    ),
                                  )
                                );
                              },
                              icon: const Icon(Icons.library_books),
                              label: const Text("Library"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7A002B),
                                side: const BorderSide(color: Color(0xFF7A002B)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 15. Buttons

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFFF6B6B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          
                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Updating event...'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                          try {
                            await _eventService.updateEvent(widget.eventId, {
                              'title': title,
                              'category': category,
                              'description': description,
                              'location': location,
                              'date': eventDate,
                              'time': eventTime != null ? '${eventTime!.hour}:${eventTime!.minute}' : null,
                              'limitedSeats': limitedSeats,
                              'seatCount': limitedSeats ? seatCount : null,
                              'collegeType': collegeType,
                              'hostingUniversity': isOtherUniversity ? _otherUniversityController.text : hostingUniversity,
                              'hostingCollege': (isOtherCollege || hostingUniversity == 'Other') ? _otherCollegeController.text : hostingCollege,
                              'audience': {
                                'students': students,
                                'outsiders': outsiders,
                                'staff': staff,
                              },
                              'paidEvent': paidEvent,
                              'feeAmount': paidEvent ? feeAmount : null,
                              'certification': certificationEvent,
                              'isTeamEvent': isTeamEvent,
                              'coordinators': coordinators,
                              'whatsapp': whatsappEnabled ? whatsappLink : null,
                              'posterUrl': widget.eventData['posterUrl'],
                              'certificateTemplateUrl': _certificateTemplateUrl,
                              'certificateFields': _certificateFields,
                            });

                            if (mounted) {
                              Navigator.pop(context); // Close loading
                              Navigator.pop(context); // Close edit screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Event updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(context); // Close loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating event: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFFF6B6B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Update Event",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _showDeleteConfirmation,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    "Delete Event",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /* ---------------- HELPERS ---------------- */

  Widget buildSection(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: const Color(0xFF7A002B),
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(
    String label, {
    String initialValue = '',
    int maxLines = 1,
    bool isNumber = false,
    IconData? icon,
    required Function(String) onSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7A002B), width: 2),
          ),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        onSaved: (v) => onSaved(v ?? ''),
      ),
    );
  }

  Widget buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged, {
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(categoryLabels[e] ?? e),
                ))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
    );
  }

  Widget buildSwitch(
    String label,
    bool value,
    IconData icon,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFF7A002B).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF7A002B) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF7A002B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF7A002B),
      ),
    );
  }

  Widget buildCheckbox(
    String label,
    bool value,
    IconData icon,
    Function(bool?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFF00D2D3).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF00D2D3) : Colors.grey.shade300,
        ),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF00D2D3)),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00D2D3),
      ),
    );
  }

  Widget buildDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Color(0xFF7A002B)),
        title: Text(
          eventDate == null
              ? "Select Date"
              : eventDate!.toLocal().toString().split(' ')[0],
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
            initialDate: eventDate ?? DateTime.now(),
          );
          if (picked != null) setState(() => eventDate = picked);
        },
      ),
    );
  }

  Widget buildTimePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Color(0xFF7A002B)),
        title: Text(
          eventTime == null ? "Select Time" : eventTime!.format(context),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: eventTime ?? TimeOfDay.now(),
          );
          if (picked != null) setState(() => eventTime = picked);
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7A002B), width: 2),
      ),
    );
  }

  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventTitle = title;
    final eventId = widget.eventId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Delete Event',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$eventTitle"?\n\nThis action cannot be undone. All registered users will be notified about the cancellation.',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Deleting event and notifying users...'),
                      ],
                    ),
                  ),
                ),
              );

              try {
                await _eventService.deleteEvent(eventId);
                
                if (mounted) {
                  // Close loading dialog first
                  Navigator.pop(context);
                  
                  // Wait a tiny bit to ensure the dialog is fully closed
                  await Future.delayed(const Duration(milliseconds: 100));
                  
                  // Return to the events screen
                  if (mounted) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Event deleted successfully.'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}


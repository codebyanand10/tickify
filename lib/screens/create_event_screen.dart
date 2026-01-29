import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'event_preview_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic details
  String title = '';
  String category = 'workshop';
  String description = '';
  String location = '';

  DateTime? eventDate;
  TimeOfDay? eventTime;

  // Toggles
  bool limitedSeats = false;
  bool paidEvent = false;
  bool certificationEvent = false;
  bool whatsappEnabled = false;

  int? seatCount;
  double? feeAmount;
  String whatsappLink = '';

  // Poster Image
  File? _posterImage;
  String? _posterImageUrl;
  bool _isUploadingPoster = false;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();

  String collegeType = 'Intra College';

  // Audience
  bool students = true;
  bool outsiders = false;
  bool staff = false;

  // Coordinators
  List<Map<String, String>> coordinators = [
    {'name': '', 'phone': ''}
  ];

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

  Future<void> _pickPosterImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _posterImage = File(image.path);
        });
        // Auto upload once picked
        await _uploadPoster();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadPoster() async {
    if (_posterImage == null) return;

    setState(() => _isUploadingPoster = true);

    try {
      final fileName = 'event_posters/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadFile(
        file: _posterImage!,
        path: fileName,
        bucket: 'certificates', // Using the same bucket we configured
      );

      setState(() {
        _posterImageUrl = url;
        _isUploadingPoster = false;
      });
    } catch (e) {
      setState(() => _isUploadingPoster = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
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
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text(
          "Create Event",
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note,
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
                            "Create Your Event",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Fill in the details below",
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

              // 0. Event Poster
              buildSection("Event Poster", icon: Icons.image),
              GestureDetector(
                onTap: _isUploadingPoster ? null : _pickPosterImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _posterImageUrl != null 
                          ? const Color(0xFF6C5CE7) 
                          : Colors.grey.shade300,
                      width: 2,
                      style: _posterImageUrl != null ? BorderStyle.solid : BorderStyle.none,
                    ),
                  ),
                  child: _isUploadingPoster
                      ? const Center(child: CircularProgressIndicator())
                      : _posterImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(_posterImageUrl!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, 
                                     size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  "Click to upload event poster",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                ),
              ),
              if (_posterImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _pickPosterImage,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text("Change Poster"),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C5CE7)),
                  ),
                ),
              const SizedBox(height: 16),

              // 1. Event title
              buildTextField(
                "Event Title",
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
                  icon: Icons.people,
                  isNumber: true,
                  onSaved: (v) => seatCount = int.parse(v),
                ),

              // 7. College type
              buildDropdown(
                "Event Type",
                ['Intra College', 'Inter College'],
                collegeType,
                (v) => setState(() => collegeType = v!),
                icon: Icons.school,
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
                  icon: Icons.currency_rupee,
                  isNumber: true,
                  onSaved: (v) => feeAmount = double.parse(v),
                ),

              // 11. Certification
              buildSwitch(
                "Certification Event",
                certificationEvent,
                Icons.verified,
                (v) => setState(() => certificationEvent = v),
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
                          onSaved: (v) => coordinators[i]['name'] = v!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
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
                          onSaved: (v) => coordinators[i]['phone'] = v!,
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
                  icon: Icons.link,
                  onSaved: (v) => whatsappLink = v,
                ),

              const SizedBox(height: 24),

              // 14. Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF6C5CE7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Save as Draft",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventPreviewScreen(
                                eventData: {
                                  'title': title,
                                  'category': category,
                                  'description': description,
                                  'location': location,
                                  'date': eventDate,
                                  'time': eventTime,
                                  'limitedSeats': limitedSeats,
                                  'seatCount': seatCount,
                                  'collegeType': collegeType,
                                  'audience': {
                                    'students': students,
                                    'outsiders': outsiders,
                                    'staff': staff,
                                  },
                                  'paidEvent': paidEvent,
                                  'feeAmount': feeAmount,
                                  'certification': certificationEvent,
                                  'coordinators': coordinators,
                                  'whatsapp': whatsappEnabled ? whatsappLink : null,
                                  'posterUrl': _posterImageUrl,
                                },
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF6C5CE7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Confirm Event",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
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
              color: const Color(0xFF6C5CE7),
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
    int maxLines = 1,
    bool isNumber = false,
    IconData? icon,
    required Function(String) onSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
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
            borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
          ),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        onSaved: (v) => onSaved(v!),
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
        initialValue: value,
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
            ? const Color(0xFF6C5CE7).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF6C5CE7) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF6C5CE7),
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
        leading: const Icon(Icons.calendar_today, color: Color(0xFF6C5CE7)),
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
            initialDate: DateTime.now(),
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
        leading: const Icon(Icons.access_time, color: Color(0xFF6C5CE7)),
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
            initialTime: TimeOfDay.now(),
          );
          if (picked != null) setState(() => eventTime = picked);
        },
      ),
    );
  }
}

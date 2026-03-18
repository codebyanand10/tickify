import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '../services/certificate_service.dart';

class TemplateSelectionScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onTemplateSelected;

  const TemplateSelectionScreen({super.key, required this.onTemplateSelected});

  @override
  State<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  
  Future<void> _showPreview(BuildContext context, Map<String, dynamic> template) async {
    showDialog(
      context: context,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = CertificateService();
      final fields = (template['fields'] as List<dynamic>).cast<Map<String, dynamic>>();
      
      final pdfBytes = await service.generateCertificatePDF(
        participantName: "JOHN DOE",
        eventName: "SAMPLE EVENT",
        eventDate: "January 01, 2026",
        organizerName: "Organizer Name",
        department: "Department",
        semester: "1",
        collegeName: "College Name",
        templateImageUrl: template['imageUrl'],
        templateFields: fields,
      );

      if (mounted) Navigator.pop(context); // Pop loading

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                AppBar(
                  title: Text(template['name'] ?? 'Template Preview'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx); // Close preview
                        widget.onTemplateSelected(template); // Select
                        Navigator.pop(context); // Close selection screen
                      },
                      child: const Text("USE TEMPLATE", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdfBytes,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: false,
                    allowSharing: false,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop loading
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error generating preview: $e")),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Certificate Template")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: CertificateService().getTemplates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("No templates found in library."),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Go Back"),
                  )
                ],
              )
            );
          }

          final templates = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final t = templates[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () => _showPreview(context, t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: t['imageUrl'] != null 
                          ? Image.network(
                              t['imageUrl'], 
                              fit: BoxFit.cover,
                              errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image)),
                            )
                          : Container(color: Colors.grey.shade200, child: const Icon(Icons.image)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] ?? 'Untitled',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(Icons.visibility, size: 14, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  "Tap to preview",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

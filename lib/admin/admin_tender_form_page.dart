import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart'; // Apnar Cloudinary Service import korun

class AdminTenderFormPage extends StatefulWidget {
  final String? tenderId;
  const AdminTenderFormPage({super.key, this.tenderId});

  @override
  State<AdminTenderFormPage> createState() => _AdminTenderFormPageState();
}

class _AdminTenderFormPageState extends State<AdminTenderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _org = TextEditingController();
  final _details = TextEditingController();

  DateTime? _endAt;
  bool _isLive = false;
  List<PlatformFile> _newFiles = [];
  List<String> _docUrls = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.tenderId != null) _load();
  }

  Future<void> _load() async {
    final d = await FirebaseFirestore.instance
        .collection('tenders')
        .doc(widget.tenderId)
        .get();
    final data = d.data();
    if (data != null) {
      setState(() {
        _title.text = data['title'] ?? '';
        _org.text = data['organization'] ?? '';
        _details.text = data['details'] ?? '';
        _endAt = (data['endAt'] as Timestamp?)?.toDate();
        _docUrls = List<String>.from(data['docUrls'] ?? []);
        _isLive = data['isLive'] ?? false;
      });
    }
  }

  // --- Mul Save Logic (Cloudinary + Firestore) ---
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields and set a deadline"),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // ১. Cloudinary-te Notun Documents Upload kora
      List<String> uploadedUrls = [..._docUrls];

      for (var file in _newFiles) {
        if (file.bytes != null) {
          // Cloudinary service call (Folder: tender_docs)
          String? url = await CloudinaryService.uploadImage(
            file.bytes!.toList(),
            folder: 'tender_docs',
          );
          if (url != null) {
            uploadedUrls.add(url);
          }
        }
      }

      // ২. Firestore Data Prepare kora
      final baseData = {
        'title': _title.text.trim(),
        'organization': _org.text.trim(),
        'details': _details.text.trim(),
        'endAt': Timestamp.fromDate(_endAt!),
        'docUrls': uploadedUrls,
        'isLive': _isLive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.tenderId == null) {
        baseData['createdAt'] = FieldValue.serverTimestamp();
        baseData['status'] = 'open';
        await FirebaseFirestore.instance.collection('tenders').add(baseData);
      } else {
        await FirebaseFirestore.instance
            .collection('tenders')
            .doc(widget.tenderId)
            .update(baseData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tender Published Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            ),
          ),
        ),
        title: Text(
          widget.tenderId == null ? 'Create New Tender' : 'Update Tender',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle("General Information"),
                _buildCard([
                  _buildTextField(
                    _title,
                    "Tender Title",
                    Icons.title,
                    "Enter project name",
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _org,
                    "Organization",
                    Icons.business,
                    "e.g. Dhaka City Corp",
                  ),
                ]),

                const SizedBox(height: 24),
                _buildSectionTitle("Tender Details"),
                _buildCard([
                  _buildTextField(
                    _details,
                    "Description",
                    Icons.description,
                    "Detailed scope of work...",
                    maxLines: 4,
                  ),
                ]),

                const SizedBox(height: 24),
                _buildSectionTitle("Settings & Deadline"),
                _buildCard([
                  _buildDateTimePicker(),
                  const Divider(height: 32),
                  SwitchListTile(
                    title: const Text(
                      "Live Auction Mode",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text("Enable real-time highest bidding"),
                    secondary: Icon(
                      Icons.sensors,
                      color: _isLive ? Colors.red : Colors.grey,
                    ),
                    value: _isLive,
                    onChanged: (v) => setState(() => _isLive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),

                const SizedBox(height: 24),
                _buildSectionTitle("Documents & Attachments"),
                _buildCard([
                  _buildFilePicker(),
                  if (_docUrls.isNotEmpty || _newFiles.isNotEmpty)
                    _buildFileList(),
                ]),

                const SizedBox(height: 100),
              ],
            ),
          ),
          _buildFloatingSaveButton(),
        ],
      ),
    );
  }

  // --- UI Helper Methods ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.indigo.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.indigo),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Required field" : null,
    );
  }

  Widget _buildDateTimePicker() {
    return InkWell(
      onTap: _pickDateTime,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_month, color: Colors.indigo),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Deadline Date & Time",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  _endAt == null
                      ? "Not Set"
                      : _endAt!.toLocal().toString().split('.')[0],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickDocs,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.indigo.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.indigo.withOpacity(0.02),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              color: Colors.indigo.shade300,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              "Tap to upload documents",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
              ),
            ),
            const Text(
              "PDF, DOCX up to 10MB",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._docUrls.map((u) => _fileChip(u.split('/').last, true)),
          ..._newFiles.map((f) => _fileChip(f.name, false)),
        ],
      ),
    );
  }

  Widget _fileChip(String name, bool isExisting) {
    return Chip(
      avatar: Icon(
        Icons.description,
        size: 14,
        color: isExisting ? Colors.green : Colors.indigo,
      ),
      label: Text(
        name,
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: isExisting
          ? Colors.green.shade50
          : Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildFloatingSaveButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.0), Colors.white],
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            child: _saving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "PUBLISH TENDER",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- Logic Helpers ---

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endAt ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    setState(() {
      _endAt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
    });
  }

  Future<void> _pickDocs() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (res != null) setState(() => _newFiles = res.files);
  }
}

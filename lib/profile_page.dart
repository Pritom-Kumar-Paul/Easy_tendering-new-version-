import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import 'services/cloudinary_service.dart';
import 'topup_request_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _nidUrl;
  String _kycStatus = 'not_uploaded';
  bool _isVerified = false;
  bool _loading = false;
  double _balance = 0.0;
  String? _verificationId;
  bool _isPhoneVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 1. Load User Data ---
  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final d = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (d.exists) {
        final data = d.data()!;
        setState(() {
          _nameController.text = data['displayName'] ?? '';
          _companyController.text = data['companyName'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _isPhoneVerified = data['phoneVerified'] ?? false;
          _nidUrl = data['nidFrontUrl'];
          _kycStatus = data['kycStatus'] ?? 'not_uploaded';
          _isVerified = data['isVerified'] ?? false;
          _balance = (data['walletBalance'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- 2. OTP Logic ---
  Future<void> _sendOTP() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      _showSnackBar("Enter phone with country code (e.g. +880)", Colors.orange);
      return;
    }
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async =>
          await _handlePhoneUpdate(credential),
      verificationFailed: (e) {
        setState(() => _loading = false);
        _showSnackBar("Failed: ${e.message}", Colors.red);
      },
      codeSent: (vid, resendToken) {
        setState(() {
          _loading = false;
          _verificationId = vid;
        });
        _showOTPDialog();
      },
      codeAutoRetrievalTimeout: (vid) => _verificationId = vid,
    );
  }

  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter OTP Code"),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final cred = PhoneAuthProvider.credential(
                verificationId: _verificationId!,
                smsCode: _otpController.text.trim(),
              );
              Navigator.pop(context);
              await _handlePhoneUpdate(cred);
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePhoneUpdate(PhoneAuthCredential credential) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
            'phoneNumber': _phoneController.text.trim(),
            'phoneVerified': true,
          });
      setState(() => _isPhoneVerified = true);
      _showSnackBar("Phone verified!", Colors.green);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- 3. NID Upload ---
  Future<void> _uploadNID() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (res == null) return;
    setState(() => _loading = true);
    try {
      String? url = await CloudinaryService.uploadImage(res.files.first.bytes!);
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({'nidFrontUrl': url, 'kycStatus': 'pending'});
        setState(() {
          _nidUrl = url;
          _kycStatus = 'pending';
        });
        _showSnackBar('NID Uploaded!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- 4. Save Profile ---
  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
            'displayName': _nameController.text.trim(),
            'companyName': _companyController.text.trim(),
          });
      _showSnackBar('Profile updated!', Colors.indigo);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 25,
                    ),
                    child: Column(
                      children: [
                        _buildBalanceCard(),
                        const SizedBox(height: 30),
                        _buildSectionHeader("Account Details"),
                        _buildCard([
                          _buildTextField(
                            _nameController,
                            "Full Name",
                            Icons.person_outline,
                          ),
                          const SizedBox(height: 15),
                          _buildPhoneField(),
                          const SizedBox(height: 15),
                          _buildTextField(
                            _companyController,
                            "Company",
                            Icons.business_outlined,
                          ),
                        ]),
                        const SizedBox(height: 30),
                        _buildSectionHeader("Verification Status"),
                        _buildNIDSection(),
                        const SizedBox(height: 40),
                        _buildActionButtons(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E3C72),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          _nameController.text.isNotEmpty ? _nameController.text : "My Profile",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Available Balance",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "৳${_balance.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3C72),
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TopUpRequestPage(),
                ),
              );
              _loadUserData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              "TOP UP",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            _phoneController,
            "Phone Number",
            Icons.phone_android,
            enabled: !_isPhoneVerified,
          ),
        ),
        if (!_isPhoneVerified) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: _sendOTP,
            child: const Text(
              "Verify",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Icon(Icons.verified, color: Colors.green),
          ),
      ],
    );
  }

  Widget _buildNIDSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isVerified ? Icons.verified_user : Icons.pending_actions,
                color: _isVerified ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Text(
                _isVerified ? "NID Verified" : "Verification: $_kycStatus",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_nidUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                _nidUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(
                Icons.image_search,
                size: 40,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 15),
          if (!_isVerified)
            TextButton.icon(
              onPressed: _uploadNID,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text("Upload New NID"),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3C72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          "SAVE CHANGES",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22, color: const Color(0xFF1E3C72)),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

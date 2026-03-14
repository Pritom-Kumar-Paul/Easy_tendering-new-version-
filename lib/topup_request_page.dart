import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TopUpRequestPage extends StatefulWidget {
  const TopUpRequestPage({super.key});

  @override
  State<TopUpRequestPage> createState() => _TopUpRequestPageState();
}

class _TopUpRequestPageState extends State<TopUpRequestPage> {
  final _amountController = TextEditingController();
  final _trxIdController = TextEditingController();
  String _selectedMethod = 'bKash';
  bool _isLoading = false;

  final List<String> _methods = ['bKash', 'Nagad', 'Rocket'];

  Future<void> _submitRequest() async {
    if (_amountController.text.isEmpty || _trxIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // wallet_requests collection-e data pathano
      await FirebaseFirestore.instance.collection('wallet_requests').add({
        'userId': user!.uid,
        'userName': user.displayName ?? "Bidder",
        'amount': double.parse(_amountController.text),
        'method': _selectedMethod,
        'trxId': _trxIdController.text.trim(),
        'status': 'pending', // Admin eita approve korbe
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request submitted! Wait for Admin approval."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Wallet Top-up"),
        backgroundColor: const Color(0xFF1E3C72),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            _buildInstructionCard(),
            const SizedBox(height: 25),

            // Input Fields
            _buildInputField(
              controller: _amountController,
              label: "Enter Amount (৳)",
              icon: Icons.add_card_rounded,
              isNumber: true,
            ),
            const SizedBox(height: 15),

            const Text(
              "Select Payment Method",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildMethodDropdown(),

            const SizedBox(height: 15),
            _buildInputField(
              controller: _trxIdController,
              label: "Transaction ID (TrxID)",
              icon: Icons.verified_user_outlined,
            ),

            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SEND REQUEST",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Components ---
  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How to add money?",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          SizedBox(height: 5),
          Text(
            "1. Send money to: 017XXXXXXXX (bKash/Nagad/Rocket)",
            style: TextStyle(fontSize: 13),
          ),
          Text(
            "2. Copy the Transaction ID (TrxID) and enter below.",
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildMethodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMethod,
          isExpanded: true,
          items: _methods
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _selectedMethod = v!),
        ),
      ),
    );
  }
}

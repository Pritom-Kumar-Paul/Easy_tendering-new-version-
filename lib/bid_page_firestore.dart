import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';

class BidPage extends StatefulWidget {
  final String tenderId;
  const BidPage({super.key, required this.tenderId});

  @override
  State<BidPage> createState() => _BidPageState();
}

class _BidPageState extends State<BidPage> {
  final _bidController = TextEditingController();
  final _noteController = TextEditingController();

  // Signature Controller
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSubmitting = false;

  // --- Bid Submit Logic ---
  Future<void> _placeBid() async {
    if (_bidController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('tenders')
          .doc(widget.tenderId)
          .collection('bids')
          .add({
            'userId': uid,
            'bidAmount': double.parse(_bidController.text),
            'note': _noteController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bid Placed Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      // Firestore theke user data real-time-e monitor kora hocche
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );

        final userData = snapshot.data!.data() as Map<String, dynamic>?;

        // Validation Flags (Admin theke isVerified true hole eta automatic update hobe)
        final bool isVerified = userData?['isVerified'] ?? false;
        final double walletBalance = (userData?['walletBalance'] ?? 0.0)
            .toDouble();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              'Live Auction Bid',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF3F51B5),
            elevation: 0,
          ),
          body: Column(
            children: [
              // --- Error Bar: Jodi verified na hoy ---
              if (!isVerified)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  color: Colors.redAccent,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.gpp_maybe_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Your NID and Phone must be verified by Admin before bidding.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Highest Bid Card
                    _buildHighestBidCard(),

                    const SizedBox(height: 25),

                    // Bid Input
                    _buildInputField(
                      controller: _bidController,
                      label: "Your Bid Amount (৳)",
                      icon: Icons.gavel_rounded,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 10),
                    Text(
                      "10% Security Deposit to be held: ৳${(_bidController.text.isEmpty ? 0 : double.tryParse(_bidController.text) ?? 0) * 0.1}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildInputField(
                      controller: _noteController,
                      label: "Note to Admin",
                      icon: Icons.note_add_rounded,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 25),
                    const Text(
                      "Digital Signature:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Signature Pad
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Signature(
                        controller: _sigController,
                        height: 150,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _sigController.clear(),
                        child: const Text(
                          "Clear Signature",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Final Place Bid Button ---
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    // Logic: Verified hole logic pabe, nahole null (disabled state)
                    onPressed: (isVerified && !_isSubmitting)
                        ? _placeBid
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isVerified
                          ? const Color(0xFF3F51B5)
                          : Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: isVerified ? 4 : 0,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.unarchive_rounded,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "PLACE BID NOW",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighestBidCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current Highest Bid",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 5),
              Text(
                "৳0.0",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(Icons.trending_up_rounded, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (v) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }
}

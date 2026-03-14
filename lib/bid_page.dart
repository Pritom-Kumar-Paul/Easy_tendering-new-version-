import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';

class BidPage extends StatefulWidget {
  final String tenderId;
  final bool isEditing;
  final String? bidId;
  final double? existingAmount;
  final String? existingNote;

  const BidPage({
    super.key,
    required this.tenderId,
    this.isEditing = false,
    this.bidId,
    this.existingAmount,
    this.existingNote,
  });

  @override
  State<BidPage> createState() => _BidPageState();
}

class _BidPageState extends State<BidPage> {
  late TextEditingController _bidController;
  late TextEditingController _noteController;
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bidController = TextEditingController(
      text: widget.isEditing ? widget.existingAmount?.toString() : "",
    );
    _noteController = TextEditingController(
      text: widget.isEditing ? widget.existingNote : "",
    );
  }

  @override
  void dispose() {
    _bidController.dispose();
    _noteController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  // --- SUBMIT / UPDATE BID WITH TRANSACTION (HOLD MONEY) ---
  Future<void> _placeBid() async {
    if (_bidController.text.isEmpty) {
      _showSnackBar("Please enter a bid amount", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";

      double bidAmount = double.parse(_bidController.text);
      double requiredDeposit = bidAmount * 0.10; // 10% calculate

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final tenderRef = FirebaseFirestore.instance
          .collection('tenders')
          .doc(widget.tenderId);

      // --- FIRESTORE TRANSACTION START ---
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. User document fetch kora balance check-er jonno
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        double currentBalance = (userSnapshot.get('walletBalance') ?? 0.0)
            .toDouble();

        // Insufficient balance hole transaction cancel hobe
        if (currentBalance < requiredDeposit) {
          throw "Insufficient Balance! You need ৳${requiredDeposit.toStringAsFixed(2)} in your wallet.";
        }

        // 2. Taka minus kora (HOLD kora)
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(-requiredDeposit),
        });

        if (widget.isEditing && widget.bidId != null) {
          // --- UPDATE LOGIC ---
          final bidDocRef = tenderRef.collection('bids').doc(widget.bidId);
          transaction.update(bidDocRef, {
            'bidAmount': bidAmount,
            'securityHold': requiredDeposit,
            'note': _noteController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // --- NEW BID LOGIC ---
          final newBidRef = tenderRef
              .collection('bids')
              .doc(); // Auto ID generate
          transaction.set(newBidRef, {
            'userId': user.uid,
            'bidderName': user.displayName ?? "Anonymous",
            'bidAmount': bidAmount,
            'securityHold': requiredDeposit,
            'note': _noteController.text.trim(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // 3. Highest bid update kora
        transaction.update(tenderRef, {'highestBid': bidAmount});
      });

      if (mounted) {
        _showSnackBar(
          widget.isEditing
              ? "Bid Updated Successfully!"
              : "Bid Placed! ৳${requiredDeposit.toStringAsFixed(2)} Held.",
          Colors.green,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
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
        final bool isVerified = userData?['isVerified'] ?? false;
        final double walletBalance = (userData?['walletBalance'] ?? 0.0)
            .toDouble();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: AppBar(
            title: Text(
              widget.isEditing ? 'Update Auction Bid' : 'Live Auction Bid',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              if (!isVerified) _buildVerificationBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildBalanceInfo(walletBalance),
                    const SizedBox(height: 25),
                    _buildInputField(
                      controller: _bidController,
                      label: "Your Bid Amount (৳)",
                      icon: Icons.gavel_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _buildSecurityNote(walletBalance),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _noteController,
                      label: "Note to Admin (Optional)",
                      icon: Icons.chat_bubble_outline_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Digital Signature",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSignaturePad(),
                  ],
                ),
              ),
              _buildSubmitButton(isVerified),
            ],
          ),
        );
      },
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildBalanceInfo(double balance) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.indigo.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.indigo,
          ),
          const SizedBox(width: 15),
          Text(
            "Wallet Balance: ৳${balance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote(double balance) {
    double bid = double.tryParse(_bidController.text) ?? 0;
    double deposit = bid * 0.1;
    bool isLow = balance < deposit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "10% Security Deposit: ৳${deposit.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 12,
            color: isLow ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isLow)
          const Text(
            "⚠️ Insufficient balance for this bid.",
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
      ],
    );
  }

  Widget _buildSignaturePad() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Signature(
            controller: _sigController,
            height: 150,
            backgroundColor: Colors.white,
          ),
          IconButton(
            onPressed: () => _sigController.clear(),
            icon: const Icon(Icons.refresh, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: (isVerified && !_isSubmitting) ? _placeBid : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isEditing
                ? Colors.orange.shade800
                : const Color(0xFF1E3C72),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  widget.isEditing ? "UPDATE BID NOW" : "PLACE BID NOW",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
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
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildVerificationBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.redAccent,
      child: const Text(
        "Admin must verify your NID before you can bid.",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

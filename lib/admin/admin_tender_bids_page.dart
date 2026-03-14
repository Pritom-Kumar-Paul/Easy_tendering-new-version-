import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminTenderBidsPage extends StatelessWidget {
  final String tenderId;
  const AdminTenderBidsPage({super.key, required this.tenderId});

  // --- Logic: Accept Winner, Deduction & Auto-Refund Others ---
  Future<void> _acceptBid(
    BuildContext context,
    String winnerUid,
    String winnerBidId,
  ) async {
    final fs = FirebaseFirestore.instance;
    final tenderRef = fs.collection('tenders').doc(tenderId);
    final bidsRef = tenderRef.collection('bids');

    try {
      // Loading indicator dekhano bhalo jeno processing somoy user wait kore
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final allBids = await bidsRef.get();
      final batch = fs.batch();

      // Winner details find kora taka deduction-er jonno
      final winnerDoc = allBids.docs.firstWhere((doc) => doc.id == winnerBidId);
      final double winnerBidAmount = (winnerDoc.data()['bidAmount'] ?? 0.0)
          .toDouble();
      final double winnerCharge =
          winnerBidAmount * 0.10; // Winner-er final 10% charge

      for (final doc in allBids.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String currentBidderId = data['userId'];
        final double currentBidAmount = (data['bidAmount'] ?? 0.0).toDouble();
        final double securityDeposit =
            currentBidAmount * 0.10; // Prottek-er 10% deposit

        if (doc.id == winnerBidId) {
          // --- 1. WINNER LOGIC ---
          batch.update(doc.reference, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Winner-er wallet theke taka kete neya (Jodi age kete na thaken)
          // Jodi BidPage-e agei minus kore thaken, tobe ekhane minus korar dorkar nei.
          // Ami dhore nichhi apni final accept-er somoy katchen:
          batch.update(fs.collection('users').doc(currentBidderId), {
            'walletBalance': FieldValue.increment(-winnerCharge),
          });
        } else {
          // --- 2. REJECTED BIDDERS LOGIC (REFUND) ---
          batch.update(doc.reference, {
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Bid place korar somoy jodi taka kete (hold) rakhen, tobe ekhane increment hobe.
          // Eti tader wallet-e automatic 10% taka back kore dibe.
          batch.update(fs.collection('users').doc(currentBidderId), {
            'walletBalance': FieldValue.increment(securityDeposit),
          });
        }
      }

      // --- 3. MAIN TENDER STATUS UPDATE ---
      batch.update(tenderRef, {
        'status': 'awarded',
        'awardedTo': winnerUid,
        'awardedAmount': winnerBidAmount,
        'securityDepositDeducted': winnerCharge,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog close
        _showSnackBar(
          context,
          "Tender Awarded! Winner charged & others refunded successfully.",
          Colors.green,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, "Error: $e", Colors.red);
      }
    }
  }

  void _showSnackBar(BuildContext context, String msg, Color color) {
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
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        title: const Text(
          'Bid Review Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tenders')
            .doc(tenderId)
            .collection('bids')
            .orderBy('bidAmount', descending: true) // Highest Bidder prothome
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty)
            return _buildEmptyState();

          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) =>
                _buildBidCard(context, docs[index]),
          );
        },
      ),
    );
  }

  Widget _buildBidCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String status = data['status'] ?? 'submitted';
    final double bidAmount = (data['bidAmount'] ?? 0.0).toDouble();
    final String userId = data['userId'] ?? 'Unknown';
    final List<String> files = List<String>.from(data['docUrls'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigo.shade50,
                      child: const Icon(Icons.person, color: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        String userName = "Loading...";
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final userData =
                              userSnap.data!.data() as Map<String, dynamic>?;
                          userName =
                              userData?['displayName'] ??
                              userData?['name'] ??
                              "ID: ${userId.substring(0, 6)}";
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "BIDDER NAME",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                _buildStatusChip(status),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.payments_outlined,
                  "Bid Amount",
                  "৳${bidAmount.toStringAsFixed(2)}",
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildWalletStream(userId),
                const SizedBox(height: 16),
                if (files.isNotEmpty) _buildAttachmentList(files),
              ],
            ),
          ),
          // Footer Action: Awarding Button
          if (status == 'submitted' || status == 'pending')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptBid(context, userId, doc.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Award Tender & Process Funds",
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
        ],
      ),
    );
  }

  // --- (Baki UI Helpers gulo ager motoi thakbe: StatusChip, DetailRow, WalletStream, EmptyState) ---
  // ...
  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'accepted') color = Colors.green;
    if (status == 'rejected') color = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color valColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletStream(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, ws) {
        final u = ws.data?.data();
        final bal = (u?['walletBalance'] ?? 0.0).toDouble();
        return _buildDetailRow(
          Icons.account_balance_wallet_outlined,
          "Current Wallet",
          "৳${bal.toStringAsFixed(2)}",
          Colors.indigo,
        );
      },
    );
  }

  Widget _buildAttachmentList(List<String> files) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          avatar: const Icon(
            Icons.file_present_rounded,
            size: 16,
            color: Colors.indigo,
          ),
          label: Text("Doc ${i + 1}", style: const TextStyle(fontSize: 12)),
          onPressed: () => launchUrl(Uri.parse(files[i])),
          backgroundColor: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "No bids submitted yet",
        style: TextStyle(color: Colors.grey, fontSize: 18),
      ),
    );
  }
}

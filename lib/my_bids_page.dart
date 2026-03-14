import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyBidsPage extends StatelessWidget {
  const MyBidsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Current User ID
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

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
        title: const Text(
          "My Bids History",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see your bids"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('bids')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("Firestore Error: ${snapshot.error}");
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final bidData = docs[index].data() as Map<String, dynamic>;
                    return _buildBidHistoryCard(bidData);
                  },
                );
              },
            ),
    );
  }

  // --- UI Components ---

  Widget _buildBidHistoryCard(Map<String, dynamic> data) {
    // ✅ CRASH FIX: Field gulo safe bhabe access kora holo
    final String status = data.containsKey('status')
        ? data['status']
        : 'pending';

    double amount = 0.0;
    if (data.containsKey('bidAmount')) {
      amount = (data['bidAmount'] ?? 0.0).toDouble();
    }

    Color statusColor = Colors.orange;
    if (status == 'accepted') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(25),
          child: Icon(Icons.gavel_rounded, color: statusColor, size: 20),
        ),
        title: const Text(
          "Tender Participation",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              "Bid Amount: ৳${amount.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.containsKey('createdAt') && data['createdAt'] != null
                  ? (data['createdAt'] as Timestamp).toDate().toString().split(
                      '.',
                    )[0]
                  : "Time unknown",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            // ✅ Refund Note for Rejected Bids
            if (status == 'rejected')
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  "10% Security Deposit Refunded",
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            "No bids found in your history",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 50,
            ),
            const SizedBox(height: 16),
            const Text(
              "Query Error / Index Required",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              error.contains('FAILED_PRECONDITION')
                  ? "Click the index link in your VS Code debug console to enable this view."
                  : "Firestore error: $error",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

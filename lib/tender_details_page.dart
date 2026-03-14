import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_7/bid_page.dart';

class TenderDetailsPage extends StatefulWidget {
  final String tenderId;
  const TenderDetailsPage({super.key, required this.tenderId});

  @override
  State<TenderDetailsPage> createState() => _TenderDetailsPageState();
}

class _TenderDetailsPageState extends State<TenderDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "Tender Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            ),
          ),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenders')
            .doc(widget.tenderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Tender not found!"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildImageHeader(data['imageUrl']),
              const SizedBox(height: 24),
              Text(
                data['title'] ?? 'Untitled Project',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3C72),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.business, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    data['organization'] ?? 'Unknown Org',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Divider(height: 40, thickness: 1),
              const Text(
                "Description",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                data['details'] ?? 'No details available for this tender.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              if (data['docUrls'] != null &&
                  (data['docUrls'] as List).isNotEmpty)
                _buildAttachmentSection(List<String>.from(data['docUrls'])),
              const SizedBox(height: 120),
            ],
          );
        },
      ),

      // --- DYNAMIC BOTTOM ACTION (PROCEED VS EDIT) ---
      bottomSheet: _buildBottomAction(context),
    );
  }

  Widget _buildImageHeader(String? url) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        image: DecorationImage(
          image: NetworkImage(
            url ?? 'https://via.placeholder.com/400x200?text=No+Image',
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tender Documents",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...urls.map(
          (url) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
              ),
              title: Text("Document ${urls.indexOf(url) + 1}"),
              trailing: const Icon(
                Icons.download_rounded,
                color: Colors.indigo,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      // Check korchi ei user age bid koreche kina
      stream: FirebaseFirestore.instance
          .collection('tenders')
          .doc(widget.tenderId)
          .collection('bids')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        bool hasAlreadyBid = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (hasAlreadyBid) {
                    // EDIT LOGIC: Age kora bid data pathiye deya hobe
                    final bidDoc = snapshot.data!.docs.first;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BidPage(
                          tenderId: widget.tenderId,
                          isEditing: true,
                          bidId: bidDoc.id,
                          existingAmount: (bidDoc['bidAmount'] ?? 0.0)
                              .toDouble(),
                          existingNote: bidDoc['note'] ?? "",
                        ),
                      ),
                    );
                  } else {
                    // NEW BID LOGIC
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BidPage(tenderId: widget.tenderId),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  // Status onujayi button color change hobe
                  backgroundColor: hasAlreadyBid
                      ? Colors.orange.shade800
                      : const Color(0xFF1E3C72),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  hasAlreadyBid ? "EDIT YOUR BID" : "PROCEED TO BID",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

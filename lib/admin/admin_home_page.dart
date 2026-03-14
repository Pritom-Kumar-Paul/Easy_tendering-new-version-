import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_tender_form_page.dart';
import 'admin_tender_bids_page.dart';
import 'admin_user_verification_page.dart';
import 'admin_wallet_panel.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Admin Console',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 80,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
            actions: [
              // 1. WALLET TOP-UP REQUEST BADGE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('wallet_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  int pendingRequests = snapshot.data?.docs.length ?? 0;
                  return _buildNotificationBadge(
                    icon: Icons.account_balance_wallet_rounded,
                    count: pendingRequests,
                    tooltip: 'Wallet Requests',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminWalletPanel(),
                      ),
                    ),
                  );
                },
              ),

              // 2. KYC VERIFICATION BADGE
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('kycStatus', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  int pendingKyc = snapshot.data?.docs.length ?? 0;
                  return _buildNotificationBadge(
                    icon: Icons.verified_user_rounded,
                    count: pendingKyc,
                    tooltip: 'User Verifications',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminUserVerificationPage(),
                      ),
                    ),
                  );
                },
              ),

              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => _showLogoutDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // --- DYNAMIC STATISTICS SECTION ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildDynamicStatsHeader(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Tenders",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text("View All")),
                ],
              ),
            ),
          ),

          _buildTenderStream(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3C72),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminTenderFormPage()),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Create Tender",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- DYNAMIC STATS LOGIC ---
  Widget _buildDynamicStatsHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tenders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LinearProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Calculations based on Status
        int total = docs.length;
        int live = docs.where((d) => d['status'] == 'open').length;
        int closed = docs
            .where((d) => d['status'] == 'closed' || d['status'] == 'awarded')
            .length;

        return Row(
          children: [
            _statCard("Total", total.toString(), Colors.blue, Icons.list_alt),
            const SizedBox(width: 12),
            _statCard("Live", live.toString(), Colors.green, Icons.sensors),
            const SizedBox(width: 12),
            _statCard(
              "Closed",
              closed.toString(),
              Colors.orange,
              Icons.do_not_disturb_on_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---
  Widget _buildNotificationBadge({
    required IconData icon,
    required int count,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 12,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTenderStream() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tenders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        final docs = snap.data!.docs;
        if (docs.isEmpty)
          return const SliverToBoxAdapter(
            child: Center(child: Text("No tenders found.")),
          );

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final data = docs[i].data();
            final status = data['status'] ?? 'open';
            final endAt = (data['endAt'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  data['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text("Org: ${data['organization'] ?? '-'}"),
                    Text(
                      "Deadline: ${endAt?.toLocal().toString().split(' ').first}",
                    ),
                    const SizedBox(height: 10),
                    _buildStatusBadge(status),
                  ],
                ),
                trailing: _buildActionMenu(context, docs[i], status),
              ),
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isOpen = status.toLowerCase() == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isOpen ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    BuildContext context,
    DocumentSnapshot d,
    String status,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.receipt_long_rounded,
            color: Colors.blueAccent,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminTenderBidsPage(tenderId: d.id),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) async {
            if (v == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminTenderFormPage(tenderId: d.id),
                ),
              );
            } else if (v == 'close') {
              await d.reference.update({'status': 'closed'});
            } else if (v == 'delete') {
              await d.reference.delete();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text("Edit")),
            if (status != 'closed')
              const PopupMenuItem(value: 'close', child: Text("Close")),
            const PopupMenuItem(
              value: 'delete',
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'tender_details_page.dart';
import 'watchlist_page.dart';
import 'profile_page.dart';
import 'my_bids_page.dart';
import 'services/watchlist_service.dart';

class TendersListPage extends StatefulWidget {
  const TendersListPage({super.key});

  @override
  State<TendersListPage> createState() => _TendersListPageState();
}

class _TendersListPageState extends State<TendersListPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tendersRef = FirebaseFirestore.instance
        .collection('tenders')
        .orderBy('endAt');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9), // Light modern background
      body: CustomScrollView(
        slivers: [
          // 1. Gorgeous Sliver AppBar with Gradient
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Open Tenders",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
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
                  child: Icon(Icons.gavel_rounded, size: 70, color: Colors.white24),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () async {
                  final q = await showSearch<String>(
                    context: context,
                    delegate: TenderSearchDelegate(),
                  );
                  if (q != null) setState(() => _q = q);
                },
              ),
              _buildTopMenu(context),
            ],
          ),

          // 2. Main Body Content
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tendersRef.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return SliverToBoxAdapter(child: _buildError(snap.error.toString()));
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())));
              }

              final docs = snap.data!.docs.where((d) {
                final status = (d['status'] ?? '').toString();
                if (status != 'open') return false;
                if (_q.isEmpty) return true;
                final t = (d['title'] ?? '').toString().toLowerCase();
                final det = (d['details'] ?? '').toString().toLowerCase();
                return t.contains(_q.toLowerCase()) || det.contains(_q.toLowerCase());
              }).toList();

              if (docs.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(50), child: Text("No tenders available"))));
              }

              return SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildTenderCard(context, docs[i]),
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildTopMenu(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (item) {
        if (item == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBidsPage()));
        if (item == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchlistPage()));
        if (item == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
        if (item == 3) FirebaseAuth.instance.signOut();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.receipt_long), title: Text("My Bids"))),
        const PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.bookmark), title: Text("Watchlist"))),
        const PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.person), title: Text("Profile"))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 3, child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text("Logout", style: TextStyle(color: Colors.red)))),
      ],
    );
  }

  Widget _buildTenderCard(BuildContext context, QueryDocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    final endAt = (data['endAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenderDetailsPage(tenderId: d.id))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3C72)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: WatchlistService.isSaved(d.id),
                      builder: (ctx, s) {
                        final saved = s.data == true;
                        return IconButton(
                          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_add_outlined, color: Color(0xFF2A5298)),
                          onPressed: () => WatchlistService.toggle(d.id),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.business_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(data['organization'] ?? '-', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            "End: ${endAt?.toLocal().toString().split(' ').first ?? '-'}",
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(child: Padding(padding: const EdgeInsets.all(20), child: SelectableText('Error: $error', style: const TextStyle(color: Colors.red))));
  }
}

// Search Delegate Implementation (Simplified for UI)
class TenderSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  @override
  Widget buildResults(BuildContext context) => Center(child: Text('Searching for "$query"...'));
  @override
  Widget buildSuggestions(BuildContext context) => Container();
}
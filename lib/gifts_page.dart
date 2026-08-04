import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';

class GiftsPage extends StatefulWidget {
  const GiftsPage({super.key});
  @override
  State<GiftsPage> createState() => _GiftsPageState();
}

class _GiftsPageState extends State<GiftsPage> {
  final _service = FirestoreService();
  String? _householdId;
  bool _loading = true;
  bool _privateUnlocked = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final hid = await _service.getPrimaryHouseholdId();
    setState(() { _householdId = hid; _loading = false; });
  }

  void _showAddDialog(String visibility) {
    final titleCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Add ${visibility == 'shared' ? 'shared' : 'private'} gift'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: detailCtrl, decoration: const InputDecoration(labelText: 'Detail')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final title = titleCtrl.text.trim();
          if (title.isEmpty) return;
          await _service.addGift(householdId: _householdId!, title: title, detail: detailCtrl.text.trim(), visibility: visibility);
          Navigator.pop(context);
        }, child: const Text('Add')),
      ],
    ));
  }

  Future<void> _unlockPrivate() async {
    final pinCtrl = TextEditingController();
    final res = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Enter PIN'),
      content: TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'PIN'), obscureText: true, keyboardType: TextInputType.number,),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verify'))],
    ));
    if (res != true) return;
    final pin = pinCtrl.text;
    final ok = await _service.verifyPin(pin);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      return;
    }
    setState(() { _privateUnlocked = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_householdId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gift ideas')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('No household found. Create one to share gifts.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () async {
            final nameCtrl = TextEditingController();
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              title: const Text('Create household'),
              content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
            ));
            if (ok == true && nameCtrl.text.trim().isNotEmpty) {
              final doc = await _service.createHousehold(name: nameCtrl.text.trim());
              setState(() { _householdId = doc.id; });
            }
          }, child: const Text('Create household')),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gift ideas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog('shared'),
        icon: const Icon(Icons.add),
        label: const Text('Add shared'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Shared gifts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _service.sharedGiftsStream(_householdId!),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Text('No shared gifts yet');
              return Column(children: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return ListTile(title: Text(data['title'] ?? ''), subtitle: Text(data['detail'] ?? ''));
              }).toList());
            },
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('My private gifts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            !_privateUnlocked
              ? TextButton(onPressed: _unlockPrivate, child: const Text('Unlock'))
              : TextButton(onPressed: () => setState(() { _privateUnlocked = false; }), child: const Text('Lock')),
          ]),
          const SizedBox(height: 8),
          if (_privateUnlocked) StreamBuilder<QuerySnapshot>(
            stream: _service.myPrivateGiftsStream(_householdId!),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Text('No private gifts yet');
              return Column(children: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return ListTile(title: Text(data['title'] ?? ''), subtitle: Text(data['detail'] ?? ''), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () async { await _service.deleteGift(householdId: _householdId!, giftId: d.id); }));
              }).toList());
            },
          ) else const Text('Private gifts are hidden'),
          const SizedBox(height: 20),
          if (_privateUnlocked) ElevatedButton(onPressed: () => _showAddDialog('private'), child: const Text('Add private gift')),
        ]),
      ),
    );
  }
}

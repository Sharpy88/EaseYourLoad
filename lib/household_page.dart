import 'package:flutter/material.dart';
import 'services/firestore_service.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage({super.key});
  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  final _service = FirestoreService();
  bool _creating = false;

  Future<void> _createHousehold() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Create household'),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Household name')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
    ));
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      setState(() { _creating = true; });
      await _service.createHousehold(name: nameCtrl.text.trim());
      setState(() { _creating = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Household created')));
    }
  }

  Future<void> _createInvite() async {
    // get household
    final hid = await _service.getPrimaryHouseholdId();
    if (hid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No household found')));
      return;
    }
    final code = await _service.createInvite(hid);
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Invite code'),
      content: SelectableText(code),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  Future<void> _joinWithCode() async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Enter invite code'),
      content: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Join'))],
    ));
    if (ok == true && codeCtrl.text.trim().isNotEmpty) {
      try {
        await _service.joinWithCode(codeCtrl.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined household')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    }
  }

  Future<void> _setPin() async {
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Set PIN'),
      content: TextField(controller: pinCtrl, decoration: const InputDecoration(labelText: 'PIN (numbers only)'), obscureText: true, keyboardType: TextInputType.number,),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Set'))],
    ));
    if (ok == true && pinCtrl.text.trim().isNotEmpty) {
      await _service.setPin(pinCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN set')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household & Invites')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ElevatedButton.icon(onPressed: _createHousehold, icon: const Icon(Icons.home), label: const Text('Create household')),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _createInvite, icon: const Icon(Icons.person_add), label: const Text('Create invite code')),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _joinWithCode, icon: const Icon(Icons.input), label: const Text('Join with code')),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _setPin, icon: const Icon(Icons.lock), label: const Text('Set / change PIN')),
        ]),
      ),
    );
  }
}

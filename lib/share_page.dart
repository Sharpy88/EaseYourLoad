import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'household_sync.dart';
import 'shared_data.dart';

class SharePage extends StatefulWidget {
  const SharePage({super.key, required this.sync, required this.currentData});

  final HouseholdSync sync;
  final SharedData Function() currentData;

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    widget.sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    try {
      final code = await widget.sync.createHousehold(widget.currentData());
      _notify('Share code $code with the person you are inviting.');
    } catch (error) {
      _notify(_describe(error));
    }
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join a household'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    try {
      await widget.sync.joinHousehold(code);
      _notify('You are now sharing this household.');
    } catch (error) {
      _notify(_describe(error));
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop sharing?'),
        content: const Text(
          'Your lists stay on this device, but you will no longer see each '
          'other’s changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stop sharing'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.sync.leaveHousehold();
    _notify('Sharing turned off on this device.');
  }

  String _describe(Object error) =>
      error is HouseholdException ? error.message : 'Something went wrong.';

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final busy = sync.state == SyncState.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Share with someone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Invite your partner or housemate so your lists, plans and budget '
            'update on both phones at the same time.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(_statusIcon(sync.state)),
              title: Text(_statusTitle(sync.state)),
              subtitle: Text(_statusDetail(sync)),
            ),
          ),
          if (sync.state == SyncState.unconfigured)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Add your Firebase project to this build to turn sharing on '
                '(see FIREBASE_SETUP.md). Everything else keeps working '
                'offline on this device.',
                style: TextStyle(color: Color(0xff69736c)),
              ),
            ),
          if (sync.isSharing) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Invite code'),
            Card(
              child: ListTile(
                title: Text(
                  sync.inviteCode ?? '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
                subtitle: const Text('They enter this code under Join'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: sync.inviteCode ?? ''),
                    );
                    _notify('Invite code copied.');
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _leave,
              icon: const Icon(Icons.link_off),
              label: const Text('Stop sharing'),
            ),
          ],
          if (sync.isConfigured && !sync.isSharing) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : _create,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite someone'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : _join,
              icon: const Icon(Icons.login),
              label: const Text('Join with an invite code'),
            ),
          ],
        ],
      ),
    );
  }

  IconData _statusIcon(SyncState state) => switch (state) {
    SyncState.shared => Icons.cloud_done_outlined,
    SyncState.busy => Icons.cloud_sync_outlined,
    SyncState.error => Icons.cloud_off_outlined,
    _ => Icons.phone_iphone_outlined,
  };

  String _statusTitle(SyncState state) => switch (state) {
    SyncState.shared => 'Sharing is on',
    SyncState.busy => 'Working…',
    SyncState.error => 'Sharing problem',
    SyncState.solo => 'Not shared yet',
    SyncState.unconfigured => 'Sharing unavailable',
  };

  String _statusDetail(HouseholdSync sync) => switch (sync.state) {
    SyncState.shared =>
      sync.memberCount <= 1
          ? 'Waiting for the other person to join with your code.'
          : '${sync.memberCount} people see these lists live.',
    SyncState.busy => 'Talking to Firebase.',
    SyncState.error => sync.errorMessage ?? 'Something went wrong.',
    SyncState.solo => 'This household is only on this device.',
    SyncState.unconfigured => 'Firebase is not configured for this build.',
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

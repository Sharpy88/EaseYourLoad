import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'shared_data.dart';

enum SyncState {
  /// Firebase has not been configured for this build, so the app stays local.
  unconfigured,

  /// Firebase is ready but this device is not part of a shared household.
  solo,

  /// Connecting or joining.
  busy,

  /// Live sync with the shared household is running.
  shared,

  /// Something went wrong; [HouseholdSync.errorMessage] explains it.
  error,
}

class HouseholdException implements Exception {
  HouseholdException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Keeps household content in sync between the people who share a household.
///
/// The whole shared payload lives in one Firestore document so that a change
/// anywhere in the app is one write and one snapshot for everybody else.
class HouseholdSync extends ChangeNotifier {
  HouseholdSync({this.writeDelay = const Duration(milliseconds: 400)});

  static const _householdKey = 'ease_your_load_household_id';
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 6;
  static const maxMembers = 4;

  final Duration writeDelay;

  /// Called with content written by another member of the household.
  void Function(SharedData data)? onRemoteData;

  SyncState _state = SyncState.unconfigured;
  String? _householdId;
  String? _errorMessage;
  int _memberCount = 0;
  String? _uid;
  bool _appliedFirstSnapshot = false;
  Timer? _writeTimer;
  SharedData? _pendingData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  SyncState get state => _state;
  String? get householdId => _householdId;
  String? get inviteCode => _householdId;
  String? get errorMessage => _errorMessage;
  int get memberCount => _memberCount;
  bool get isSharing => _householdId != null;
  bool get isConfigured => _state != SyncState.unconfigured;

  CollectionReference<Map<String, dynamic>> get _households =>
      FirebaseFirestore.instance.collection('households');

  /// Starts Firebase (when configured) and resumes an existing household.
  Future<void> initialize() async {
    if (DefaultFirebaseOptions.currentPlatform.apiKey.isEmpty) {
      _set(SyncState.unconfigured);
      return;
    }
    _set(SyncState.busy);
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final credential = await FirebaseAuth.instance.signInAnonymously();
      _uid = credential.user?.uid;
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_householdKey);
      if (saved == null) {
        _set(SyncState.solo);
        return;
      }
      _householdId = saved;
      _listen();
    } catch (error) {
      _fail('Could not connect to the shared household. $error');
    }
  }

  /// Creates a household seeded with the content already on this device and
  /// returns the invite code to share.
  Future<String> createHousehold(SharedData current) async {
    _requireReady();
    _set(SyncState.busy);
    try {
      final code = await _reserveCode(current);
      _householdId = code;
      await _remember(code);
      _listen();
      return code;
    } catch (error) {
      _fail('Could not create the shared household. $error');
      rethrow;
    }
  }

  /// Joins the household behind [code]. Its content replaces what is on this
  /// device, so both people see the same lists.
  Future<void> joinHousehold(String code) async {
    _requireReady();
    final normalized = code.trim().toUpperCase();
    _set(SyncState.busy);
    try {
      final document = _households.doc(normalized);
      final snapshot = await document.get();
      if (!snapshot.exists) {
        throw HouseholdException('That invite code does not exist.');
      }
      final members = _membersOf(snapshot.data());
      if (!members.contains(_uid) && members.length >= maxMembers) {
        throw HouseholdException('That household is already full.');
      }
      await document.update({'members': FieldValue.arrayUnion([_uid])});
      _householdId = normalized;
      await _remember(normalized);
      _listen();
    } on HouseholdException catch (error) {
      _fail(error.message);
      rethrow;
    } catch (error) {
      _fail('Could not join that household. $error');
      rethrow;
    }
  }

  /// Leaves the shared household; the content stays on this device.
  Future<void> leaveHousehold() async {
    final id = _householdId;
    await _stopListening();
    _householdId = null;
    _appliedFirstSnapshot = false;
    _memberCount = 0;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_householdKey);
    _set(SyncState.solo);
    if (id != null && _uid != null) {
      try {
        await _households.doc(id).update({
          'members': FieldValue.arrayRemove([_uid]),
        });
      } catch (_) {
        // Leaving locally is enough; the membership tidy-up is best effort.
      }
    }
  }

  /// Queues [data] to be shared with the household.
  void push(SharedData data) {
    if (!isSharing) return;
    _pendingData = data;
    _writeTimer?.cancel();
    _writeTimer = Timer(writeDelay, _flush);
  }

  Future<void> _flush() async {
    final data = _pendingData;
    final id = _householdId;
    if (data == null || id == null) return;
    _pendingData = null;
    try {
      await _households.doc(id).set({
        'data': data.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      }, SetOptions(merge: true));
    } catch (error) {
      _fail('Could not save the shared changes. $error');
    }
  }

  Future<String> _reserveCode(SharedData current) async {
    final random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(
        _codeLength,
        (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
      ).join();
      final document = _households.doc(code);
      if ((await document.get()).exists) continue;
      await document.set({
        'members': [_uid],
        'data': current.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
      return code;
    }
    throw HouseholdException('Could not generate an invite code. Try again.');
  }

  void _listen() {
    final id = _householdId;
    if (id == null) return;
    _appliedFirstSnapshot = false;
    _subscription?.cancel();
    _subscription = _households.doc(id).snapshots().listen(
      _handleSnapshot,
      onError: (Object error) =>
          _fail('Lost the connection to the shared household. $error'),
    );
  }

  void _handleSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      _fail('The shared household was removed.');
      return;
    }
    final document = snapshot.data() ?? const {};
    _memberCount = _membersOf(document).length;
    _errorMessage = null;
    _set(SyncState.shared);
    if (snapshot.metadata.hasPendingWrites) return;
    // Our own writes are already reflected locally; applying them again could
    // undo an edit made while the write was in flight.
    final isOwnWrite = document['updatedBy'] == _uid;
    if (isOwnWrite && _appliedFirstSnapshot) return;
    final data = document['data'];
    if (data is! Map) return;
    _appliedFirstSnapshot = true;
    onRemoteData?.call(SharedData.fromJson(Map<String, dynamic>.from(data)));
  }

  List<String> _membersOf(Map<String, dynamic>? document) {
    final members = document?['members'];
    if (members is! List) return const [];
    return members.whereType<String>().toList();
  }

  Future<void> _remember(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_householdKey, id);
  }

  void _requireReady() {
    if (!isConfigured) {
      throw HouseholdException(
        'Firebase is not configured for this build yet.',
      );
    }
  }

  Future<void> _stopListening() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    _pendingData = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _set(SyncState state) {
    _state = state;
    if (state != SyncState.error) _errorMessage = null;
    notifyListeners();
  }

  void _fail(String message) {
    _errorMessage = message;
    _state = SyncState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}

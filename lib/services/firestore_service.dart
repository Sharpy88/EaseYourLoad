import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  Future<String?> getPrimaryHouseholdId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    // Prefer explicit user households list
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null && data['households'] is List && (data['households'] as List).isNotEmpty) {
        return (data['households'] as List).first as String;
      }
    }
    // Fallback: find a household where user is a member
    final q = await _db.collection('households').where('members', arrayContains: uid).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first.id;
    return null;
  }

  Future<DocumentReference> createHousehold({required String name}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _db.collection('households').add({
      'name': name,
      'ownerUid': uid,
      'members': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    // add to user doc
    await _db.collection('users').doc(uid).set({
      'households': FieldValue.arrayUnion([doc.id])
    }, SetOptions(merge: true));
    return doc;
  }

  Future<String> createInvite(String householdId) async {
    final callable = _functions.httpsCallable('createInvite');
    final res = await callable.call({'householdId': householdId});
    return (res.data as Map)['code'] as String;
  }

  Future<void> joinWithCode(String code) async {
    final callable = _functions.httpsCallable('joinWithCode');
    await callable.call({'code': code});
  }

  Future<void> setPin(String pin) async {
    final callable = _functions.httpsCallable('setPin');
    await callable.call({'pin': pin});
  }

  Future<bool> verifyPin(String pin) async {
    final callable = _functions.httpsCallable('verifyPin');
    final res = await callable.call({'pin': pin});
    return (res.data as Map)['valid'] as bool? ?? false;
  }

  Stream<QuerySnapshot> sharedGiftsStream(String householdId) {
    return _db.collection('households').doc(householdId).collection('gifts')
      .where('visibility', isEqualTo: 'shared')
      .orderBy('createdAt', descending: true)
      .snapshots();
  }

  Stream<QuerySnapshot> myPrivateGiftsStream(String householdId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db.collection('households').doc(householdId).collection('gifts')
      .where('visibility', isEqualTo: 'private')
      .where('createdBy', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
  }

  Future<void> addGift({required String householdId, required String title, required String detail, required String visibility}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('households').doc(householdId).collection('gifts').add({
      'title': title,
      'detail': detail,
      'visibility': visibility,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGift({required String householdId, required String giftId}) async {
    await _db.collection('households').doc(householdId).collection('gifts').doc(giftId).delete();
  }

  Future<void> updateGift({required String householdId, required String giftId, required Map<String, dynamic> data}) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('households').doc(householdId).collection('gifts').doc(giftId).update(data);
  }
}

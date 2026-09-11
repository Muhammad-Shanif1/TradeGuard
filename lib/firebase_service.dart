import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trading_models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // --- TRADES ---

  Future<void> saveTrade(Trade trade) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('trades')
        .doc(trade.id)
        .set(trade.toMap());
  }

  Future<void> deleteTrade(String id) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('trades')
        .doc(id)
        .delete();
  }

  Stream<List<Trade>> streamTrades() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_uid)
        .collection('trades')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Trade.fromMap(doc.data())).toList());
  }

  // --- SETTINGS ---

  Future<void> saveSettings(AccountSettings settings, TradingLimits limits) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'account': settings.toMap(),
      'limits': limits.toMap(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getSettings() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).get();
    return doc.data();
  }

  // --- CHECKLIST ---

  Future<void> saveChecklistState(Map<String, bool> state) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'checklist': state,
      'checklistTimestamp': FieldValue.serverTimestamp(),
    }).catchError((_) => _db.collection('users').doc(_uid).set({
      'checklist': state,
      'checklistTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

  Stream<Map<String, bool>> streamChecklist() {
    if (_uid == null) return Stream.value({});
    return _db.collection('users').doc(_uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null || data['checklist'] == null) return {};
      return Map<String, bool>.from(data['checklist']);
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

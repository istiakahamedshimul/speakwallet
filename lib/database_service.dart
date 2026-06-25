import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DatabaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.refFromURL('https://speakwalletapp-default-rtdb.firebaseio.com/');

  // --- AUDIO PROCESSING ---
  Future<String> uploadAndAnalyzeAudio(String filePath) async {
    try {
      var uri = Uri.parse('http://98.70.27.72:8000/process-audio');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));

      if (streamedResponse.statusCode == 200) {
        var response = await http.Response.fromStream(streamedResponse);
        await saveTransaction(json.decode(response.body));
        return "Success";
      } else if (streamedResponse.statusCode == 429) {
        return "Quota Full";
      }
      return "Error: ${streamedResponse.statusCode}";
    } catch (e) {
      print("❌ Audio Upload Error: $e");
      return "Connection Failed";
    }
  }

  // --- IMAGE PROCESSING (RECEIPTS) ---
  Future<String> uploadAndAnalyzeReceipt(String filePath) async {
    try {
      var uri = Uri.parse('http://98.70.27.72:8000/process-receipt');
      print("🚀 Sending receipt to: $uri");

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));

      if (streamedResponse.statusCode == 200) {
        var response = await http.Response.fromStream(streamedResponse);
        await saveTransaction(json.decode(response.body));
        return "Success";
      } else if (streamedResponse.statusCode == 429) {
        return "Quota Full";
      } else {
        return "Error: ${streamedResponse.statusCode}";
      }
    } catch (e) {
      print("❌ Image Upload Error: $e");
      return "Connection Failed";
    }
  }

  // --- SAVE NEW TRANSACTION ---
  Future<void> saveTransaction(Map<String, dynamic> data) async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);

    final batch = _firestore.batch();
    DocumentReference firestoreDateDoc = _firestore.collection('users').doc(uid).collection('history').doc(dateKey);

    try {
      if (data['category'] == 'expense') {
        for (var item in data['items']) {
          String titleText = "${item['item_bn']} (${item['item_en']})";
          _writeToDatabases(batch, firestoreDateDoc, uid, dateKey, 'expense', titleText, item['amount']);
        }
      } else {
        _writeToDatabases(batch, firestoreDateDoc, uid, dateKey, data['category'], data['person'] ?? "Unknown", data['amount'] ?? 0);
      }
      await batch.commit();
    } catch (e) {
      print("Database Save Error: $e");
    }
  }

  void _writeToDatabases(WriteBatch batch, DocumentReference dateDoc, String uid, String dateKey, String type, String title, dynamic amount) {
    // Generate a unique ID so Firestore and RTDB match exactly!
    var fsRef = dateDoc.collection('transactions').doc();
    String uniqueId = fsRef.id;

    var transactionData = {
      'id': uniqueId,
      'type': type,
      'title': title,
      'amount': (amount ?? 0).toDouble(),
      'date': dateKey,
      'is_deleted': 0, // 0 = Active, 1 = Soft Deleted
    };

    // Save to Firestore
    batch.set(fsRef, {...transactionData, 'timestamp': FieldValue.serverTimestamp()});

    // Save to RTDB using the exact same ID
    _rtdb.child('users/$uid/history/$dateKey/transactions/$uniqueId').set({
      ...transactionData,
      'timestamp': ServerValue.timestamp
    });
  }

  // --- UPDATE TRANSACTION (Offline Ready) ---
  void updateTransaction(String id, String dateKey, String newTitle, double newAmount) {
    final uid = _auth.currentUser!.uid;

    // Queue Firestore Update
    _firestore.collection('users').doc(uid)
        .collection('history').doc(dateKey)
        .collection('transactions').doc(id)
        .update({'title': newTitle, 'amount': newAmount});

    // Queue RTDB Update
    _rtdb.child('users/$uid/history/$dateKey/transactions/$id')
        .update({'title': newTitle, 'amount': newAmount});

    print("Update queued locally. Will sync when online.");
  }

  // --- SOFT DELETE TRANSACTION (Offline Ready) ---
  void softDeleteTransaction(String id, String dateKey) {
    final uid = _auth.currentUser!.uid;

    // Queue Firestore Soft Delete
    _firestore.collection('users').doc(uid)
        .collection('history').doc(dateKey)
        .collection('transactions').doc(id)
        .update({'is_deleted': 1});

    // Queue RTDB Soft Delete
    _rtdb.child('users/$uid/history/$dateKey/transactions/$id')
        .update({'is_deleted': 1});

    print("Delete queued locally. Will sync when online.");
  }
}
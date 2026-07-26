import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'settings.dart';
import '../models/call.dart';
import '../models/customer.dart';
import '../models/call_update.dart';

final syncServiceProvider = Provider((ref) => SyncService(ref));

// We now stream the calls directly from Firestore.
final callsStreamProvider = StreamProvider<List<Call>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.streamCalls();
});

// For backward compatibility with widgets that expected callsProvider as StateNotifier
// We can just watch the stream provider instead, but let's provide a proxy if needed.
// Actually, it's cleaner to update the UI to use `ref.watch(callsStreamProvider)`.
// But for now, we can create a simpler callsProvider.
final callsProvider = Provider<List<Call>>((ref) {
  final asyncValue = ref.watch(callsStreamProvider);
  return asyncValue.value ?? [];
});

final techniciansProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.streamTechnicians();
});

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Ref ref;
  
  SyncService(this.ref);

  SettingsService get _settings => ref.read(settingsProvider);

  Future<void> initPushNotifications() async {
    final role = await _settings.getRole();
    if (role != 'technician') return;

    final techName = await _settings.getAssignedTechnician();
    if (techName == null || techName.isEmpty) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        // Query tech and update their token
        final snapshot = await _firestore.collection('technicians').where('name', isEqualTo: techName).get();
        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.update({'fcm_token': token});
        }
      }
    }
  }

  Stream<List<Call>> streamCalls() async* {
    final role = await _settings.getRole();
    Query query = _firestore.collection('calls').orderBy('created_at', descending: true);

    if (role == 'technician') {
      final techName = await _settings.getAssignedTechnician();
      if (techName != null && techName.isNotEmpty) {
        query = query.where('technician_assigned', isEqualTo: techName);
      }
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Call.fromJson(doc.data() as Map<String, dynamic>, docId: doc.id);
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamTechnicians() {
    return _firestore.collection('technicians').orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<bool> addTechnician(String name, String pin) async {
    try {
      final existing = await _firestore.collection('technicians').where('name', isEqualTo: name).get();
      if (existing.docs.isNotEmpty) return false;

      await _firestore.collection('technicians').add({
        'name': name,
        'pin': pin,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Add technician error: $e');
      return false;
    }
  }

  Future<bool> deleteTechnician(String id) async {
    try {
      await _firestore.collection('technicians').doc(id).delete();
      return true;
    } catch (e) {
      print('Delete technician error: $e');
      return false;
    }
  }

  Stream<Call?> streamCallDetail(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Call.fromJson(doc.data() as Map<String, dynamic>, docId: doc.id);
    });
  }

  Future<Call?> createCall(Map<String, dynamic> payload) async {
    try {
      final data = {
        'call_type': payload['call_type'] ?? 'Other',
        'problem_description': payload['problem_description'] ?? '',
        'priority': payload['priority'] ?? 'Medium',
        'status': 'Pending',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'customer': {
          'name': payload['customer_name'] ?? 'Unknown',
          'phone': payload['phone_number'] ?? '',
        },
        'technician_assigned': payload['technician_assigned'],
        'updates': [
          {
            'note': 'Call created.',
            'status_change': 'Pending',
            'timestamp': FieldValue.serverTimestamp(),
          }
        ]
      };
      
      final docRef = await _firestore.collection('calls').add(data);
      
      await _notifyIfRequired(data['priority'] as String?, data['technician_assigned'] as String?, data['problem_description'] as String?);
      
      final docSnap = await docRef.get();
      return Call.fromJson(docSnap.data() as Map<String, dynamic>, docId: docSnap.id);
    } catch (e) {
      print('Create call error: $e');
      return null;
    }
  }

  Future<Call?> updateCall(String callId, Map<String, dynamic> payload) async {
    try {
      final docRef = _firestore.collection('calls').doc(callId);
      final updateData = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      if (payload['status'] != null) updateData['status'] = payload['status'];
      if (payload['priority'] != null) updateData['priority'] = payload['priority'];
      if (payload['technician_assigned'] != null) updateData['technician_assigned'] = payload['technician_assigned'];

      final newUpdate = {
        'note': payload['note'] ?? 'Updated',
        'status_change': payload['status'],
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Call does not exist!");
        
        final existingUpdates = List.from(snapshot.data()?['updates'] ?? []);
        existingUpdates.insert(0, newUpdate); // Add to top
        updateData['updates'] = existingUpdates;
        
        transaction.update(docRef, updateData);
      });
      
      if (payload['technician_assigned'] != null || payload['priority'] == 'High') {
         await _notifyIfRequired(payload['priority'] ?? 'High', payload['technician_assigned'], payload['note']);
      }
      
      final docSnap = await docRef.get();
      return Call.fromJson(docSnap.data() as Map<String, dynamic>, docId: docSnap.id);
    } catch (e) {
      print('Update call error: $e');
      return null;
    }
  }

  Future<void> deleteCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).delete();
    } catch (e) {
      print('Delete call error: $e');
    }
  }

  Future<void> syncPendingActions(WidgetRef ref) async {
    // Offline caching is automatically handled by Firestore. No logic needed here!
  }

  Future<Map<String, dynamic>> extractCallInfo(String rawText) async {
    try {
      final baseUrl = await _settings.getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/calls/extract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'raw_text': rawText}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Extract info error: $e');
    }
    return {};
  }

  Future<void> _notifyIfRequired(String? priority, String? techName, String? problemDesc) async {
    if (priority == 'High' && techName != null && techName.isNotEmpty) {
      try {
        final baseUrl = await _settings.getBaseUrl();
        await http.post(
          Uri.parse('$baseUrl/notify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'technician_assigned': techName,
            'title': 'New High Priority Call',
            'body': problemDesc ?? 'Urgent call assigned.',
          }),
        );
      } catch (e) {
        print('Notify error: $e');
      }
    }
  }
}

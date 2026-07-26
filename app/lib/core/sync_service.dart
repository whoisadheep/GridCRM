import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'database.dart';
import 'settings.dart';
import '../models/call.dart';
import '../models/customer.dart';

final syncServiceProvider = Provider((ref) => SyncService());
final callsProvider = StateNotifierProvider<CallsNotifier, List<Call>>((ref) {
  return CallsNotifier(ref.watch(syncServiceProvider));
});
final techniciansProvider = StateNotifierProvider<TechniciansNotifier, List<Map<String, dynamic>>>((ref) {
  return TechniciansNotifier(ref.watch(syncServiceProvider));
});
final pendingSyncProvider = StateProvider<bool>((ref) => false);

class CallsNotifier extends StateNotifier<List<Call>> {
  final SyncService _syncService;

  CallsNotifier(this._syncService) : super([]) {
    loadCalls();
  }

  Future<void> loadCalls() async {
    // Immediate local read
    final cached = await _syncService.getCachedCalls();
    state = cached;
    
    // Background refresh
    final updated = await _syncService.fetchAndCacheCalls();
    if (updated != null) {
      state = updated;
    }
  }

  void optimisticallyAddCall(Call call) {
    state = [call, ...state];
  }
}

class TechniciansNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final SyncService _syncService;

  TechniciansNotifier(this._syncService) : super([]) {
    loadTechnicians();
  }

  Future<void> loadTechnicians() async {
    final techs = await _syncService.fetchTechnicians();
    state = techs;
  }

  Future<bool> addTechnician(String name, String pin) async {
    final tech = await _syncService.addTechnician(name, pin);
    if (tech != null) {
      state = [...state, tech];
      return true;
    }
    return false;
  }

  Future<bool> deleteTechnician(int id) async {
    final success = await _syncService.deleteTechnician(id);
    if (success) {
      state = state.where((t) => t['id'] != id).toList();
    }
    return success;
  }
}

class SyncService {
  final _dbHelper = DatabaseHelper.instance;
  final _settings = SettingsService();

  Future<bool> isOnline() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<List<Call>> getCachedCalls() async {
    final data = await _dbHelper.getCachedCalls();
    return data.map((e) => Call.fromJson(e)).toList();
  }

  Future<void> initPushNotifications() async {
    final role = await _settings.getRole();
    if (role != 'technician') return;

    final techName = await _settings.getAssignedTechnician();
    if (techName == null || techName.isEmpty) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null && await isOnline()) {
        final baseUrl = await _settings.getBaseUrl();
        await http.put(
          Uri.parse('$baseUrl/technicians/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': techName, 'fcm_token': token}),
        );
      }
    }
  }

  Future<List<Call>?> fetchAndCacheCalls() async {
    if (!await isOnline()) return null;

    try {
      final baseUrl = await _settings.getBaseUrl();
      final role = await _settings.getRole();
      
      String url = '$baseUrl/calls';
      if (role == 'technician') {
        final techName = await _settings.getAssignedTechnician();
        if (techName != null && techName.isNotEmpty) {
          url += '?technician_assigned=${Uri.encodeComponent(techName)}';
        }
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await _dbHelper.cacheCalls(data);
        return data.map((e) => Call.fromJson(e)).toList();
      }
    } catch (e) {
      print('Fetch error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchTechnicians() async {
    if (!await isOnline()) return [];
    try {
      final baseUrl = await _settings.getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/technicians'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Fetch technicians error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> addTechnician(String name, String pin) async {
    if (!await isOnline()) return null;
    try {
      final baseUrl = await _settings.getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/technicians'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'pin': pin}),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Add technician error: $e');
    }
    return null;
  }

  Future<bool> deleteTechnician(int id) async {
    if (!await isOnline()) return false;
    try {
      final baseUrl = await _settings.getBaseUrl();
      final response = await http.delete(Uri.parse('$baseUrl/technicians/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print('Delete technician error: $e');
    }
    return false;
  }

  Future<Call?> getCallDetail(int callId) async {
    // Fast path local
    final localData = await _dbHelper.getCachedCallDetail(callId);
    Call? localCall;
    if (localData != null) {
      localCall = Call.fromJson(localData);
    }

    if (!await isOnline()) return localCall;

    try {
      final baseUrl = await _settings.getBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/calls/$callId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _dbHelper.cacheCallDetail(callId, data);
        return Call.fromJson(data);
      }
    } catch (e) {
      print('Fetch detail error: $e');
    }
    return localCall;
  }

  Future<Call?> createCall(Map<String, dynamic> payload) async {
    if (await isOnline()) {
      try {
        final baseUrl = await _settings.getBaseUrl();
        final response = await http.post(
          Uri.parse('$baseUrl/calls'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          // Return the true created call
          return Call.fromJson(data);
        }
      } catch (e) {
        print('Create call network error: $e');
      }
    }

    // Offline or failed -> Queue
    await _dbHelper.addPendingAction('create_call', payload);
    
    // Optimistic return
    final fakeId = DateTime.now().millisecondsSinceEpoch;
    final fakeCall = Call(
      id: fakeId, // Fake ID
      callType: payload['call_type'] ?? 'Other',
      problemDescription: payload['problem_description'] ?? '',
      priority: payload['priority'] ?? 'Medium',
      status: 'Pending',
      createdAt: DateTime.now().toIso8601String(),
      customer: Customer(
        id: fakeId,
        name: payload['customer_name'] ?? 'Unknown',
        phone: payload['phone_number'] ?? '',
      ),
    );

    // Cache the detail locally so CallDetailScreen can load it
    await _dbHelper.cacheCallDetail(fakeId, {
      'id': fakeId,
      'call_type': fakeCall.callType,
      'problem_description': fakeCall.problemDescription,
      'priority': fakeCall.priority,
      'status': fakeCall.status,
      'created_at': fakeCall.createdAt,
      'customer': {
        'name': payload['customer_name'] ?? 'Unknown',
        'phone': payload['phone_number'] ?? '',
      },
      'updates': [],
    });

    return fakeCall;
  }

  Future<Call?> updateCall(int callId, Map<String, dynamic> payload) async {
    if (await isOnline()) {
      try {
        final baseUrl = await _settings.getBaseUrl();
        final response = await http.post(
          Uri.parse('$baseUrl/calls/$callId/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _dbHelper.cacheCallDetail(callId, data); // refresh detail cache
          return Call.fromJson(data);
        }
      } catch (e) {
         print('Update call network error: $e');
      }
    }

    // Offline or failed -> Queue
    payload['call_id'] = callId;
    await _dbHelper.addPendingAction('update_call', payload);
    
    // Optimistically update the local cache so UI reflects it immediately
    final localData = await _dbHelper.getCachedCallDetail(callId);
    if (localData != null) {
      if (payload['status'] != null) {
        localData['status'] = payload['status'];
      }
      if (payload['priority'] != null) {
        localData['priority'] = payload['priority'];
      }
      final newUpdate = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'call_id': callId,
        'note': payload['note'] ?? 'Updated',
        'status_change': payload['status'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final updates = List<Map<String, dynamic>>.from(localData['updates'] ?? []);
      updates.insert(0, newUpdate); // Add at the top (latest first)
      localData['updates'] = updates;
      
      await _dbHelper.cacheCallDetail(callId, localData);
      return Call.fromJson(localData);
    }

    return null;
  }

  Future<void> deleteCall(int callId) async {
    // Optimistically delete from cache
    await _dbHelper.deleteCachedCall(callId);

    if (await isOnline()) {
      try {
        final baseUrl = await _settings.getBaseUrl();
        final response = await http.delete(Uri.parse('$baseUrl/calls/$callId'));
        if (response.statusCode == 200 || response.statusCode == 404) {
          return; // Success
        }
      } catch (e) {
        print('Delete call network error: $e');
      }
    }

    // Queue for offline sync
    await _dbHelper.addPendingAction('delete_call', {'call_id': callId});
  }

  Future<Map<String, dynamic>?> extractCallInfo(String text) async {
    if (!await isOnline()) return null;

    try {
      final baseUrl = await _settings.getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/calls/extract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'raw_text': text}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Extraction error: $e');
    }
    return null;
  }

  Future<void> syncPendingActions(WidgetRef ref) async {
    if (!await isOnline()) return;

    final actions = await _dbHelper.getPendingActions();
    if (actions.isEmpty) {
      ref.read(pendingSyncProvider.notifier).state = false;
      return;
    }

    ref.read(pendingSyncProvider.notifier).state = true;
    final baseUrl = await _settings.getBaseUrl();

    for (var action in actions) {
      final type = action['action_type'];
      final payload = jsonDecode(action['payload']);
      final id = action['id'];

      try {
        if (type == 'create_call') {
          final response = await http.post(
            Uri.parse('$baseUrl/calls'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
          if (response.statusCode == 201) {
            await _dbHelper.markActionSynced(id);
          }
        } else if (type == 'update_call') {
          final callId = payload.remove('call_id');
          final response = await http.post(
            Uri.parse('$baseUrl/calls/$callId/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
          if (response.statusCode == 200) {
            await _dbHelper.markActionSynced(id);
          }
        } else if (type == 'delete_call') {
          final callId = payload['call_id'];
          final response = await http.delete(Uri.parse('$baseUrl/calls/$callId'));
          if (response.statusCode == 200 || response.statusCode == 404) {
            await _dbHelper.markActionSynced(id);
          }
        }
      } catch (e) {
        print('Sync failed for action $id: $e');
        // Stop syncing on first error to maintain order
        break; 
      }
    }

    // Check if any left
    final left = await _dbHelper.getPendingActions();
    ref.read(pendingSyncProvider.notifier).state = left.isNotEmpty;
    
    // Refresh calls now that we've synced
    ref.read(callsProvider.notifier).loadCalls();
  }
}

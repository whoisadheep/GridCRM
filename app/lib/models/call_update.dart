import 'package:cloud_firestore/cloud_firestore.dart';

class CallUpdate {
  final String? id;
  final String? callId;
  final String note;
  final String? statusChange;
  final String? timestamp;

  CallUpdate({
    this.id,
    this.callId,
    required this.note,
    this.statusChange,
    this.timestamp,
  });

  factory CallUpdate.fromJson(Map<String, dynamic> json, {String? docId}) {
    String? parseDate(dynamic dateStr) {
      if (dateStr == null) return null;
      if (dateStr is Timestamp) return dateStr.toDate().toIso8601String();
      return dateStr.toString();
    }

    return CallUpdate(
      id: docId ?? json['id']?.toString(),
      callId: json['call_id']?.toString(),
      note: json['note'],
      statusChange: json['status_change'],
      timestamp: parseDate(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_id': callId,
      'note': note,
      'status_change': statusChange,
      'timestamp': timestamp,
    };
  }
}

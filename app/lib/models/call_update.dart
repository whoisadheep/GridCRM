class CallUpdate {
  final int? id;
  final int? callId;
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

  factory CallUpdate.fromJson(Map<String, dynamic> json) {
    return CallUpdate(
      id: json['id'],
      callId: json['call_id'],
      note: json['note'],
      statusChange: json['status_change'],
      timestamp: json['timestamp'],
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

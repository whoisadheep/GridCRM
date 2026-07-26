import 'customer.dart';
import 'call_update.dart';

class Call {
  final int? id;
  final int? customerId;
  final String callType;
  final String problemDescription;
  final String priority;
  final String? technicianAssigned;
  final String status;
  final String? rawInput;
  final String? createdAt;
  final String? updatedAt;
  final Customer? customer;
  final List<CallUpdate>? updates;

  Call({
    this.id,
    this.customerId,
    required this.callType,
    required this.problemDescription,
    required this.priority,
    this.technicianAssigned,
    required this.status,
    this.rawInput,
    this.createdAt,
    this.updatedAt,
    this.customer,
    this.updates,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'],
      customerId: json['customer_id'],
      callType: json['call_type'] ?? 'Other',
      problemDescription: json['problem_description'] ?? '',
      priority: json['priority'] ?? 'Medium',
      technicianAssigned: json['technician_assigned'],
      status: json['status'] ?? 'Pending',
      rawInput: json['raw_input'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      customer: json['customer'] != null ? Customer.fromJson(json['customer']) : null,
      updates: json['updates'] != null 
          ? (json['updates'] as List).map((i) => CallUpdate.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'call_type': callType,
      'problem_description': problemDescription,
      'priority': priority,
      'technician_assigned': technicianAssigned,
      'status': status,
      'raw_input': rawInput,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'customer': customer?.toJson(),
      'updates': updates?.map((u) => u.toJson()).toList(),
    };
  }
}

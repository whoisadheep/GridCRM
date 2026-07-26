import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String? id;
  final String? name;
  final String phone;
  final String? address;
  final String? createdAt;
  final List<dynamic>? pastCalls;

  Customer({
    this.id,
    this.name,
    required this.phone,
    this.address,
    this.createdAt,
    this.pastCalls,
  });

  factory Customer.fromJson(Map<String, dynamic> json, {String? docId}) {
    String? parseDate(dynamic dateStr) {
      if (dateStr == null) return null;
      if (dateStr is Timestamp) return dateStr.toDate().toIso8601String();
      return dateStr.toString();
    }

    return Customer(
      id: docId ?? json['id']?.toString(),
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      createdAt: parseDate(json['created_at']),
      pastCalls: json['past_calls'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'created_at': createdAt,
      'past_calls': pastCalls,
    };
  }
}

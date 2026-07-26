class Customer {
  final int? id;
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

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      createdAt: json['created_at'],
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

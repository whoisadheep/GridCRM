import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';
import '../../models/customer.dart';
import 'call_detail_screen.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final Customer customer;

  const CustomerProfileScreen({super.key, required this.customer});

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    final allCalls = ref.watch(callsProvider);
    
    // Filter calls for this customer (match by name or phone)
    final history = allCalls.where((c) {
      if (c.customer == null) return false;
      return c.customer!.name == customer.name || c.customer!.phone == customer.phone;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Profile Card
            ClayContainer(
              color: baseColor,
              borderRadius: 24,
              depth: 30,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    ClayContainer(
                      color: baseColor,
                      height: 80,
                      width: 80,
                      borderRadius: 40,
                      depth: -20,
                      child: const Icon(Icons.person, size: 40, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      customer.name ?? 'Unknown',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      customer.phone ?? 'No Phone',
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ClayContainer(
                      color: baseColor,
                      borderRadius: 12,
                      depth: -5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'Total Lifetime Calls: ${history.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Call History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              const Text('No historical calls found.')
            else
              ...history.map((call) {
                final callId = call.id ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CallDetailScreen(callId: callId)),
                      );
                    },
                    child: ClayContainer(
                      color: baseColor,
                      borderRadius: 16,
                      depth: 10,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(call.problemDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('${call.callType} • ${call.createdAt ?? 'Unknown date'}'),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClayContainer(
                              color: _getPriorityColor(call.priority),
                              borderRadius: 12,
                              depth: 5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(call.priority, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(call.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

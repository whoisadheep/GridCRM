import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';
import '../../models/call.dart';
import 'technician_management_screen.dart';
import '../widgets/trial_banner.dart';
import '../widgets/download_progress_banner.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Widget _buildSection(BuildContext context, String title, Widget child) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    return ClayContainer(
      color: baseColor,
      borderRadius: 20,
      depth: 15,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCallTypeChart(List<Call> calls, BuildContext context) {
    final types = ['Service', 'Installation', 'AMC', 'Sales', 'Other'];
    final Map<String, int> typeCounts = {for (var t in types) t: 0};
    for (var c in calls) {
      if (typeCounts.containsKey(c.callType)) {
        typeCounts[c.callType] = typeCounts[c.callType]! + 1;
      } else {
        typeCounts['Other'] = typeCounts['Other']! + 1;
      }
    }
    
    final maxCount = typeCounts.values.reduce((a, b) => a > b ? a : b);
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Column(
      children: typeCounts.entries.map((entry) {
        final percentage = maxCount == 0 ? 0.0 : entry.value / maxCount;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              SizedBox(
                width: 85, 
                child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  children: [
                    ClayContainer(
                      color: baseColor,
                      height: 14,
                      borderRadius: 7,
                      depth: -20, // inset background
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: ClayContainer(
                        color: const Color(0xFF4285F4),
                        height: 14,
                        borderRadius: 7,
                        depth: 10,
                        surfaceColor: Colors.blue[300],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                child: Text(entry.value.toString(), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityBreakdown(List<Call> calls, BuildContext context) {
    final high = calls.where((c) => c.priority == 'High').length;
    final medium = calls.where((c) => c.priority == 'Medium').length;
    final low = calls.where((c) => c.priority == 'Low').length;
    final total = calls.length;

    if (total == 0) return const Text('No data');

    Widget segment(Color color, int count) {
      if (count == 0) return const SizedBox.shrink();
      return Expanded(
        flex: count,
        child: Container(
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    Widget legendItem(String label, int count, Color color) {
      return Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label ($count)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClayContainer(
          color: Theme.of(context).scaffoldBackgroundColor,
          height: 24,
          borderRadius: 12,
          depth: -10,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                segment(Colors.redAccent, high),
                segment(Colors.orangeAccent, medium),
                segment(Colors.grey, low),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            legendItem('High', high, Colors.redAccent),
            legendItem('Medium', medium, Colors.orangeAccent),
            legendItem('Low', low, Colors.grey),
          ],
        )
      ],
    );
  }

  Widget _buildTopCustomers(List<Call> calls, BuildContext context) {
    final Map<String, int> customerCounts = {};
    for (var c in calls) {
      final name = c.customer?.name ?? 'Unknown';
      if (name.isNotEmpty) {
        customerCounts[name] = (customerCounts[name] ?? 0) + 1;
      }
    }

    var sorted = customerCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var top3 = sorted.take(3).toList();

    if (top3.isEmpty) return const Text('No customers yet.', style: TextStyle(color: Colors.black54));

    return Column(
      children: top3.asMap().entries.map((entry) {
        int index = entry.key;
        var c = entry.value;
        Color medalColor = index == 0 ? Colors.amber : (index == 1 ? Colors.blueGrey[300]! : Colors.brown[300]!);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              ClayContainer(
                color: Theme.of(context).scaffoldBackgroundColor,
                height: 40, width: 40,
                borderRadius: 20,
                depth: 10,
                child: Icon(Icons.emoji_events, color: medalColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(c.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ClayContainer(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: 12,
                depth: -5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Text('${c.value} calls', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(callsProvider);
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    final resolved = calls.where((c) => c.status == 'Resolved').length;
    final total = calls.length;
    final resolutionRate = total == 0 ? 0 : ((resolved / total) * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Technicians',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TechnicianManagementScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TrialBanner(),
            const DownloadProgressBanner(),
            const SizedBox(height: 16),
            // KPI Header
            Row(
              children: [
                Expanded(
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 20,
                    depth: 25,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text('Resolution Rate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 8),
                          Text('$resolutionRate%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 20,
                    depth: 25,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text('Total Volume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 8),
                          Text('$total', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(context, 'Call Volume by Type', _buildCallTypeChart(calls, context)),
            const SizedBox(height: 32),
            _buildSection(context, 'Priority Distribution', _buildPriorityBreakdown(calls, context)),
            const SizedBox(height: 32),
            _buildSection(context, 'Top Customers', _buildTopCustomers(calls, context)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

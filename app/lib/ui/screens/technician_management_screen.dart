import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';

class TechnicianManagementScreen extends ConsumerStatefulWidget {
  const TechnicianManagementScreen({super.key});

  @override
  ConsumerState<TechnicianManagementScreen> createState() => _TechnicianManagementScreenState();
}

class _TechnicianManagementScreenState extends ConsumerState<TechnicianManagementScreen> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  Future<void> _addTechnician() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty || pin.isEmpty) return;

    final success = await ref.read(techniciansProvider.notifier).addTechnician(name, pin);
    if (success) {
      _nameCtrl.clear();
      _pinCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician added')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add technician')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final techs = ref.watch(techniciansProvider);
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Technicians', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            ClayContainer(
              color: baseColor,
              borderRadius: 12,
              depth: 20,
              emboss: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'New technician name',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '4-digit PIN',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _addTechnician(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF4285F4)),
                      onPressed: _addTechnician,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: techs.isEmpty
                  ? const Center(child: Text('No technicians saved yet.', style: TextStyle(color: Colors.black54)))
                  : ListView.builder(
                      itemCount: techs.length,
                      itemBuilder: (context, index) {
                        final t = techs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Dismissible(
                            key: Key(t['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              ref.read(techniciansProvider.notifier).deleteTechnician(t['id']);
                            },
                            child: ClayContainer(
                              color: baseColor,
                              borderRadius: 16,
                              depth: 10,
                              child: ListTile(
                                leading: const Icon(Icons.person, color: Colors.black54),
                                title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

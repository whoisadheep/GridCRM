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

  Future<void> _showTechnicianDialog({Map<String, dynamic>? tech}) async {
    final isEdit = tech != null;
    final editNameCtrl = TextEditingController(text: tech?['name'] ?? '');
    final editPinCtrl = TextEditingController(text: tech?['pin'] ?? '');
    final editPhoneCtrl = TextEditingController(text: tech?['phone'] ?? '');
    final editEmailCtrl = TextEditingController(text: tech?['email'] ?? '');
    final editSpecialtyCtrl = TextEditingController(text: tech?['specialty'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Technician' : 'Add Technician'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editNameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                TextField(
                  controller: editPinCtrl,
                  decoration: const InputDecoration(labelText: 'PIN *'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: editPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: editEmailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: editSpecialtyCtrl,
                  decoration: const InputDecoration(labelText: 'Specialty (e.g., CCTV, AMC)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      }
    );

    if (result == true) {
      final name = editNameCtrl.text.trim();
      final pin = editPinCtrl.text.trim();
      final phone = editPhoneCtrl.text.trim();
      final email = editEmailCtrl.text.trim();
      final specialty = editSpecialtyCtrl.text.trim();

      if (name.isEmpty || pin.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and PIN are required.')));
        }
        return;
      }

      try {
        bool success = false;
        if (isEdit) {
          success = await ref.read(syncServiceProvider).updateTechnician(
            tech!['id'], name, pin, phone: phone, email: email, specialty: specialty
          );
        } else {
          success = await ref.read(syncServiceProvider).addTechnician(
            name, pin, phone: phone, email: email, specialty: specialty
          );
        }

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? 'Technician updated' : 'Technician added'))
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operation failed. Name might be taken.'))
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showTechnicianOptions(BuildContext context, Map<String, dynamic> t, Color baseColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ClayContainer(
                color: baseColor,
                height: 80,
                width: 80,
                borderRadius: 40,
                depth: 20,
                child: const Icon(Icons.person, size: 40, color: Colors.blueAccent),
              ),
              const SizedBox(height: 16),
              Text(t['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (t['specialty'] != null && t['specialty'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(t['specialty'], style: const TextStyle(fontSize: 16, color: Colors.black54)),
                ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showTechnicianDialog(tech: t);
                      },
                      child: ClayContainer(
                        color: baseColor,
                        height: 60,
                        borderRadius: 12,
                        depth: 15,
                        curveType: CurveType.convex,
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(syncServiceProvider).deleteTechnician(t['id']);
                      },
                      child: ClayContainer(
                        color: baseColor,
                        height: 60,
                        borderRadius: 12,
                        depth: 15,
                        curveType: CurveType.convex,
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final techsAsync = ref.watch(techniciansProvider);
    final techs = techsAsync.value ?? [];
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Technicians', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add New Technician', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showTechnicianDialog(),
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
                              ref.read(syncServiceProvider).deleteTechnician(t['id']);
                            },
                            child: ClayContainer(
                              color: baseColor,
                              borderRadius: 16,
                              depth: 10,
                              child: ListTile(
                                leading: const Icon(Icons.person, color: Colors.black54),
                                title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: t['specialty'] != null && t['specialty'].toString().isNotEmpty
                                    ? Text(t['specialty'])
                                    : null,
                                trailing: const Icon(Icons.more_vert, color: Colors.black38),
                                onTap: () => _showTechnicianOptions(context, t, baseColor),
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

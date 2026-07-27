import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/sync_service.dart';
import '../../core/settings.dart';
import '../../models/call.dart';
import 'customer_profile_screen.dart';

class CallDetailScreen extends ConsumerStatefulWidget {
  final String callId;

  const CallDetailScreen({super.key, required this.callId});

  @override
  ConsumerState<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends ConsumerState<CallDetailScreen> {
  Call? _call;
  bool _loading = true;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final syncService = ref.read(syncServiceProvider);
    // Firestore streams automatically, we can just use the stream instead of a future,
    // but to keep it simple, we listen to it.
    syncService.streamCallDetail(widget.callId).listen((call) {
      if (mounted) {
        setState(() {
          _call = call;
          _loading = false;
        });
      }
    });
  }

  Future<void> _addUpdate(String? statusChange) async {
    if (_noteCtrl.text.isEmpty && statusChange == null) return;

    final syncService = ref.read(syncServiceProvider);
    final payload = {
      'note': _noteCtrl.text.isNotEmpty ? _noteCtrl.text : 'Status updated to $statusChange',
    };
    if (statusChange != null) {
      payload['status'] = statusChange;
    }

    _noteCtrl.clear();
    
    await syncService.updateCall(widget.callId, payload);
    
    // The stream listener above will automatically trigger _loadDetail/rebuild
  }

  Future<void> _reassignTechnician(String? techName) async {
    if (techName == null || techName == _call?.technicianAssigned) return;
    
    final syncService = ref.read(syncServiceProvider);
    final payload = {
      'note': 'Re-assigned to $techName',
      'technician_assigned': techName,
    };
    
    await syncService.updateCall(widget.callId, payload);
  }

  Widget _statusButton(String label, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _addUpdate(label),
        child: ClayContainer(
          color: color,
          height: 60,
          borderRadius: 16,
          depth: 15,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_call == null) return const Scaffold(body: Center(child: Text('Call not found or pending sync')));

    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    final techsAsync = ref.watch(techniciansProvider);
    final techs = techsAsync.value ?? [];
    final techNames = techs.map((t) => t['name'] as String).toList();
    
    final availableTechs = List<String>.from(techNames);
    if (_call!.technicianAssigned != null && _call!.technicianAssigned!.isNotEmpty && !availableTechs.contains(_call!.technicianAssigned)) {
      availableTechs.add(_call!.technicianAssigned!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Call #${_call!.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (ref.read(roleProvider) == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Call?'),
                  content: const Text('Are you sure you want to delete this call?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text('Delete', style: TextStyle(color: Colors.red))
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final syncService = ref.read(syncServiceProvider);
                await syncService.deleteCall(widget.callId);
                if (mounted) Navigator.pop(context);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Info
            GestureDetector(
              onTap: () {
                if (_call?.customer != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CustomerProfileScreen(customer: _call!.customer!)),
                  );
                }
              },
              child: ClayContainer(
                color: baseColor,
                borderRadius: 16,
                depth: 20,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_call!.customer?.name ?? 'Unknown', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_call!.customer?.phone ?? ''),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Problem: ${_call!.problemDescription}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Status: ${_call!.status} | Priority: ${_call!.priority}'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Fast Status Actions
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                _statusButton('In Progress', Colors.blue),
                const SizedBox(width: 16),
                _statusButton('Wait Parts', Colors.orange),
                const SizedBox(width: 16),
                _statusButton('Resolved', Colors.green),
              ],
            ),
            const SizedBox(height: 32),
            
            if (ref.read(roleProvider) == 'admin') ...[
              // Re-assign Technician
              const Text('Assign Technician', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ClayContainer(
                color: baseColor,
                borderRadius: 12,
                depth: 15,
                emboss: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: (_call!.technicianAssigned != null && _call!.technicianAssigned!.isNotEmpty) ? _call!.technicianAssigned : null,
                      hint: const Text('Unassigned'),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Unassigned')),
                        ...availableTechs.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      ],
                      onChanged: (v) => _reassignTechnician(v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            
            // Note Input
            Row(
              children: [
                Expanded(
                  child: ClayContainer(
                    color: baseColor,
                    borderRadius: 12,
                    depth: 15,
                    emboss: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add a note...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _addUpdate(null),
                  child: ClayContainer(
                    color: const Color(0xFF4285F4),
                    height: 50,
                    width: 50,
                    borderRadius: 25,
                    depth: 15,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            if (_call!.updates != null)
              ..._call!.updates!.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ClayContainer(
                  color: baseColor,
                  borderRadius: 12,
                  depth: 10,
                  child: ListTile(
                    title: Text(u.note, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(u.timestamp ?? '', style: const TextStyle(fontSize: 12)),
                    trailing: u.statusChange != null ? ClayContainer(
                      color: Colors.blueAccent,
                      borderRadius: 8,
                      depth: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(u.statusChange!, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ) : null,
                  ),
                ),
              )),
              
            if (_call!.customer?.pastCalls != null && _call!.customer!.pastCalls!.isNotEmpty) ...[
              const SizedBox(height: 32),
              ClayContainer(
                color: baseColor,
                borderRadius: 16,
                depth: 15,
                child: ExpansionTile(
                  title: const Text('Past Calls from Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  children: _call!.customer!.pastCalls!.map((c) => ListTile(
                    title: Text(c['problem_description'] ?? ''),
                    subtitle: Text(c['status'] ?? ''),
                  )).toList(),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

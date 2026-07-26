import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/sync_service.dart';
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

  Future<void> _shareToWhatsApp() async {
    final phone = _call?.customer?.phone;
    if (phone == null || phone.isEmpty) return;
    
    // Clean phone number (remove non-digits, possibly keeping + for country code if we want, but let's just use it directly)
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    final tech = _call?.technicianAssigned ?? 'one of our technicians';
    final problem = _call?.problemDescription ?? 'your inquiry';
    
    final text = 'Hello ${_call?.customer?.name ?? ''}, your inquiry regarding "$problem" has been registered. $tech will be assigned shortly.';
    final encodedText = Uri.encodeComponent(text);
    
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedText');
    
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not installed or could not be opened.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_call == null) return const Scaffold(body: Center(child: Text('Call not found or pending sync')));

    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Call #${_call!.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
                          if (_call!.customer?.phone != null && _call!.customer!.phone!.isNotEmpty)
                            GestureDetector(
                              onTap: _shareToWhatsApp,
                              child: ClayContainer(
                                color: const Color(0xFF25D366), // WhatsApp Green
                                borderRadius: 10,
                                depth: 10,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat, size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            )
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

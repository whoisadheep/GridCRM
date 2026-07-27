import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';
import '../../core/settings.dart';
import '../../models/call.dart';
import 'quick_create_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'call_detail_screen.dart';
import '../widgets/assistant_sheet.dart';

class CallListScreen extends ConsumerStatefulWidget {
  const CallListScreen({super.key});

  @override
  ConsumerState<CallListScreen> createState() => _CallListScreenState();
}

class _CallListScreenState extends ConsumerState<CallListScreen> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String _statusFilter = 'Pending';
  String _role = 'admin';

  @override
  void initState() {
    super.initState();
    _loadRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).initPushNotifications();
    });
  }

  Future<void> _loadRole() async {
    final settings = ref.read(settingsProvider);
    final role = await settings.getRole();
    if (mounted) {
      setState(() {
        _role = role;
      });
    }
  }

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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Calls?'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} calls?'),
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
      for (final id in _selectedIds) {
        await syncService.deleteCall(id);
      }
      
      setState(() {
        _selectedIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var calls = ref.watch(callsProvider);
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    
    // Apply Filters
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      calls = calls.where((c) {
        final matchName = c.customer?.name?.toLowerCase().contains(q) ?? false;
        final matchPhone = c.customer?.phone?.toLowerCase().contains(q) ?? false;
        final matchDesc = c.problemDescription.toLowerCase().contains(q);
        return matchName || matchPhone || matchDesc;
      }).toList();
    }
    
    if (_statusFilter != 'All') {
      calls = calls.where((c) => c.status == _statusFilter).toList();
    }

    final isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? '${_selectedIds.length} Selected' : 'Calls', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: isSelectionMode ? [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteSelected,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedIds.clear()),
          ),
        ] : [
          if (_role == 'admin')
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.blue),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AssistantSheet(),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadRole();
            },
          ),
          if (_role != 'technician')
            IconButton(
              icon: const Icon(Icons.dashboard),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClayContainer(
                  color: baseColor,
                  borderRadius: 12,
                  depth: -10,
                  emboss: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Colors.grey),
                        hintText: 'Search customer, phone, or problem...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Pending', 'In Progress', 'Wait Parts', 'Resolved'].map((status) {
                      final isSelected = _statusFilter == status;
                      
                      // Calculate count using the unfiltered calls from the provider
                      final allCalls = ref.watch(callsProvider);
                      final count = status == 'All' 
                          ? allCalls.length 
                          : allCalls.where((c) => c.status == status).length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _statusFilter = status),
                          child: ClayContainer(
                            color: isSelected ? Colors.blue.withOpacity(0.2) : baseColor,
                            borderRadius: 12,
                            depth: isSelected ? -5 : 10,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                '$status ($count)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.blue[800] : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _selectedIds.clear());
              },
              child: calls.isEmpty 
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      Center(
                        child: ClayContainer(
                          color: baseColor,
                          height: 120,
                          width: 120,
                          borderRadius: 60,
                          depth: -20,
                          child: const Icon(Icons.inbox_outlined, size: 60, color: Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'No calls found!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap the + button to log a new call\nor change your filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: calls.length,
                    itemBuilder: (context, index) {
                  final call = calls[index];
                  final callId = call.id ?? '';
                  final isSelected = _selectedIds.contains(callId);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: GestureDetector(
                      onLongPress: () {
                        if (_role == 'admin') {
                          _toggleSelection(callId);
                        }
                      },
                      onTap: () {
                        if (isSelectionMode) {
                          _toggleSelection(callId);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallDetailScreen(callId: callId),
                            ),
                          );
                        }
                      },
                      child: Dismissible(
                        key: Key(callId),
                        direction: call.status == 'Resolved' 
                            ? DismissDirection.none 
                            : DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          final syncService = ref.read(syncServiceProvider);
                          if (direction == DismissDirection.endToStart) {
                            // Swipe Left -> Mark High Priority
                            await syncService.updateCall(callId, {
                              'priority': 'High',
                              'note': 'Priority escalated to High via quick swipe.'
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as High Priority')));
                            }
                          } else if (direction == DismissDirection.startToEnd) {
                            // Swipe Right -> Mark Resolved
                            await syncService.updateCall(callId, {
                              'status': 'Resolved',
                              'note': 'Marked as Resolved via quick swipe.'
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Resolved')));
                            }
                          }
                          return false; // Return false so the item isn't removed from the tree manually
                        },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.check_circle, color: Colors.white, size: 30),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.priority_high, color: Colors.white, size: 30),
                        ),
                        child: ClayContainer(
                          color: isSelected ? Colors.blue.withOpacity(0.1) : baseColor,
                          borderRadius: 16,
                          depth: isSelected ? -5 : 20,
                          spread: 4,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(call.customer?.name ?? 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(call.customer?.phone ?? ''),
                                const SizedBox(height: 4),
                                Text(
                                  call.problemDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: isSelected ? 
                              const Icon(Icons.check_circle, color: Colors.blue, size: 30) : 
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClayContainer(
                                    color: _getPriorityColor(call.priority),
                                    borderRadius: 12,
                                    depth: 10,
                                    emboss: true,
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
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (isSelectionMode || _role == 'technician') ? null : SafeArea(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickCreateScreen()),
            );
          },
          child: ClayContainer(
            color: const Color(0xFF4285F4),
            height: 60,
            width: 60,
            borderRadius: 30,
            depth: 40,
            curveType: CurveType.convex,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

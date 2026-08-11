import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../core/sync_service.dart';
import '../../core/settings.dart';
import '../../models/call.dart';
import 'quick_create_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'call_detail_screen.dart';
import '../widgets/assistant_sheet.dart';
import '../widgets/trial_banner.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/download_progress_banner.dart';
import '../../core/app_update_service.dart';

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
  String? _techName;

  @override
  void initState() {
    super.initState();
    _loadRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = ref.read(roleProvider);
      if (role == 'technician') {
        ref.read(syncServiceProvider).enablePushNotifications();
      }
      ref.read(appUpdateServiceProvider).checkAndShowUpdateModal(context);
    });
  }

  Future<void> _loadRole() async {
    final settings = ref.read(settingsProvider);
    final role = await settings.getRole();
    final techName = await settings.getAssignedTechnician();
    if (mounted) {
      setState(() {
        _role = role;
        _techName = techName;
      });
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFF9800);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Calls?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${_selectedIds.length} calls?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
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
    
    if (_role == 'technician' && _techName != null) {
      calls = calls.where((c) => c.technicianAssigned == _techName).toList();
    }

    final isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.7)),
          ),
        ),
        title: Text(isSelectionMode ? '${_selectedIds.length} Selected' : 'Calls', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: isSelectionMode ? [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteSelected,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () => setState(() => _selectedIds.clear()),
          ),
        ] : [
          if (_role == 'admin')
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
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
            icon: const Icon(Icons.settings, color: Colors.black87),
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
              icon: const Icon(Icons.dashboard, color: Colors.black87),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              ),
            )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F4FF), Color(0xFFFAFAFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TrialBanner(),
              const DownloadProgressBanner(),
              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ]
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                          hintText: 'Search customer, phone, or problem...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['All', 'Pending', 'In Progress', 'Wait Parts', 'Resolved'].map((status) {
                          final isSelected = _statusFilter == status;
                          
                          // Calculate count using the relevant calls
                          var baseCalls = ref.watch(callsProvider);
                          if (_role == 'technician' && _techName != null) {
                            baseCalls = baseCalls.where((c) => c.technicianAssigned == _techName).toList();
                          }
                          final count = status == 'All' 
                              ? baseCalls.length 
                              : baseCalls.where((c) => c.status == status).length;

                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: GestureDetector(
                              onTap: () => setState(() => _statusFilter = status),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                                decoration: BoxDecoration(
                                  gradient: isSelected 
                                      ? const LinearGradient(colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)])
                                      : const LinearGradient(colors: [Colors.white, Colors.white]),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: const Color(0xFF8E2DE2).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ] : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                  border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  '$status ($count)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey[700],
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
                            child: Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                                ]
                              ),
                              child: const Icon(Icons.inbox_outlined, size: 60, color: Colors.blueAccent),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _role == 'technician' ? 'No assigned calls!' : 'No calls found!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _role == 'technician' 
                                ? 'You have no calls assigned right now.\nTake a break or check back later!'
                                : 'Tap the + button to log a new call\nor change your filters.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100, top: 12),
                        physics: const BouncingScrollPhysics(),
                        itemCount: calls.length,
                        itemBuilder: (context, index) {
                      final call = calls[index];
                      final callId = call.id ?? '';
                      final isSelected = _selectedIds.contains(callId);
                      final isResolved = call.status == 'Resolved';
                      
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
                            direction: isResolved 
                                ? DismissDirection.none 
                                : DismissDirection.horizontal,
                            confirmDismiss: (direction) async {
                              final syncService = ref.read(syncServiceProvider);
                              if (direction == DismissDirection.endToStart) {
                                await syncService.updateCall(callId, {
                                  'priority': 'High',
                                  'note': 'Priority escalated to High via quick swipe.'
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as High Priority')));
                                }
                              } else if (direction == DismissDirection.startToEnd) {
                                await syncService.updateCall(callId, {
                                  'status': 'Resolved',
                                  'note': 'Marked as Resolved via quick swipe.'
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Resolved')));
                                }
                              }
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              decoration: BoxDecoration(color: const Color(0xFF00C853), borderRadius: BorderRadius.circular(24)),
                              child: const Icon(Icons.check_circle, color: Colors.white, size: 30),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(24)),
                              child: const Icon(Icons.priority_high, color: Colors.white, size: 30),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: isSelected 
                                    ? Border.all(color: Colors.blueAccent, width: 2)
                                    : Border.all(color: Colors.transparent, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  )
                                ]
                              ),
                              child: Stack(
                                children: [
                                  // Premium High Priority Badge
                                  if (!isResolved && call.priority.toLowerCase() == 'high')
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF4B2B).withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4)
                                            )
                                          ]
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF36D1DC), Color(0xFF5B86E5)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF5B86E5).withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4)
                                              )
                                            ]
                                          ),
                                          child: Center(
                                            child: Text(
                                              call.customer?.name?.isNotEmpty == true 
                                                  ? call.customer!.name![0].toUpperCase() 
                                                  : '?',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        
                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                call.customer?.name ?? 'Unknown Customer', 
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(call.customer?.phone ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                call.problemDescription,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.black54, height: 1.4),
                                              ),
                                              const SizedBox(height: 16),
                                              
                                              // Footer: Status Badge
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isResolved ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      call.status, 
                                                      style: TextStyle(
                                                        fontSize: 12, 
                                                        fontWeight: FontWeight.w700, 
                                                        color: isResolved ? const Color(0xFF2E7D32) : Colors.black54
                                                      )
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                        
                                        // Trailing Check
                                        if (isSelected)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 12.0, top: 12.0),
                                            child: Icon(Icons.check_circle, color: Colors.blueAccent, size: 28),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
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
        ),
      ),
      floatingActionButton: (isSelectionMode || _role == 'technician') ? null : GestureDetector(
        onTap: () {
          final trialStatus = ref.read(trialStatusProvider);
          if (trialStatus.isExpired) {
            showDialog(
              context: context,
              builder: (_) => const UpgradeDialog(),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickCreateScreen()),
            );
          }
        },
        child: Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0072FF).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ]
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

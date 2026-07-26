import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';
import 'call_detail_screen.dart';

class ConfirmScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialData;

  const ConfirmScreen({super.key, required this.initialData});

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  TextEditingController? _nameCtrl;
  TextEditingController? _phoneCtrl;
  late TextEditingController _problemCtrl;
  String? _selectedTech;
  String _callType = 'Other';
  String _priority = 'Medium';
  bool _saving = false;

  final List<String> callTypes = ['Service', 'Installation', 'AMC', 'Sales', 'Other'];
  final List<String> priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _problemCtrl = TextEditingController(text: widget.initialData['problem_description'] ?? '');
    _selectedTech = widget.initialData['technician_assigned'];
    if (_selectedTech != null && _selectedTech!.isEmpty) {
      _selectedTech = null;
    }

    if (callTypes.contains(widget.initialData['call_type'])) {
      _callType = widget.initialData['call_type'];
    }
    if (priorities.contains(widget.initialData['priority'])) {
      _priority = widget.initialData['priority'];
    }
  }

  Future<void> _saveCall() async {
    if (_phoneCtrl == null || _phoneCtrl!.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone is required')));
      return;
    }

    setState(() => _saving = true);
    final syncService = ref.read(syncServiceProvider);
    
    final payload = {
      'customer_name': _nameCtrl?.text ?? '',
      'phone_number': _phoneCtrl?.text ?? '',
      'call_type': _callType,
      'priority': _priority,
      'problem_description': _problemCtrl.text,
      'technician_assigned': _selectedTech,
      'raw_input': widget.initialData['raw_input'] ?? '',
    };

    final call = await syncService.createCall(payload);
    
    if (mounted) {
      if (call != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CallDetailScreen(callId: call.id ?? '')),
        );
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed.')));
      }
    }
  }

  Widget _buildClayInput({required Widget child, double height = 60}) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    return ClayContainer(
      color: baseColor,
      borderRadius: 12,
      depth: 20,
      emboss: true,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calls = ref.watch(callsProvider);
    final techsAsync = ref.watch(techniciansProvider);
    final techs = techsAsync.value ?? [];
    final techNames = techs.map((t) => t['name'] as String).toList();
    
    // If AI assigned a tech that isn't in our loaded list yet (or was deleted),
    // we still need it in the dropdown to avoid an assertion error.
    final availableTechs = List<String>.from(techNames);
    if (_selectedTech != null && !availableTechs.contains(_selectedTech)) {
      availableTechs.add(_selectedTech!);
    }

    final Map<String, String> customers = {};
    for (var call in calls) {
      if (call.customer?.name != null && call.customer!.name!.isNotEmpty) {
        customers[call.customer!.name!] = call.customer!.phone ?? '';
      }
    }
    final uniqueCustomers = customers.entries.map((e) => {'name': e.key, 'phone': e.value}).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Details', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _saving 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildClayInput(
                child: Autocomplete<Map<String, String>>(
                  initialValue: TextEditingValue(text: widget.initialData['phone_number'] ?? ''),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, String>>.empty();
                    }
                    return uniqueCustomers.where((c) => c['phone']!.contains(textEditingValue.text));
                  },
                  displayStringForOption: (option) => option['phone']!,
                  onSelected: (option) {
                    if (_nameCtrl != null && (_nameCtrl!.text.isEmpty || _nameCtrl!.text == widget.initialData['customer_name'])) {
                      _nameCtrl!.text = option['name']!;
                    }
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    _phoneCtrl = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: InputBorder.none),
                      keyboardType: TextInputType.phone,
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 48),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text('${option['phone']} (${option['name']})'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildClayInput(
                child: Autocomplete<Map<String, String>>(
                  initialValue: TextEditingValue(text: widget.initialData['customer_name'] ?? ''),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, String>>.empty();
                    }
                    return uniqueCustomers.where((c) => c['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (option) => option['name']!,
                  onSelected: (option) {
                    if (_phoneCtrl != null && (_phoneCtrl!.text.isEmpty || _phoneCtrl!.text == widget.initialData['phone_number'])) {
                      _phoneCtrl!.text = option['phone']!;
                    }
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    _nameCtrl = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      decoration: const InputDecoration(labelText: 'Customer Name', border: InputBorder.none),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 48),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text('${option['name']} (${option['phone']})'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildClayInput(
                child: DropdownButtonFormField<String>(
                  value: _callType,
                  items: callTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _callType = v!),
                  decoration: const InputDecoration(labelText: 'Call Type', border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 16),
              _buildClayInput(
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  items: priorities.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                  decoration: const InputDecoration(labelText: 'Priority', border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 16),
              _buildClayInput(
                child: DropdownButtonFormField<String>(
                  value: _selectedTech,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Unassigned')),
                    ...availableTechs.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  ],
                  onChanged: (v) => setState(() => _selectedTech = v),
                  decoration: const InputDecoration(labelText: 'Technician Assigned (Optional)', border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 16),
              _buildClayInput(
                height: 100,
                child: TextField(
                  controller: _problemCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Problem Description', border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _saveCall,
                child: ClayContainer(
                  color: const Color(0xFF4285F4),
                  height: 60,
                  borderRadius: 30,
                  depth: 20,
                  curveType: CurveType.convex,
                  child: const Center(
                    child: Text(
                      'Save call',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
    );
  }
}

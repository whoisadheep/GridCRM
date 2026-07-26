import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/settings.dart';
import 'call_list_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isAdmin = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final settings = ref.read(settingsProvider);
      final baseUrl = await settings.getBaseUrl();
      
      final Map<String, dynamic> body = {
        'role': _isAdmin ? 'admin' : 'technician',
      };
      
      if (_isAdmin) {
        body['username'] = _usernameController.text;
        body['password'] = _passwordController.text;
      } else {
        body['name'] = _nameController.text;
        body['pin'] = _pinController.text;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        await settings.setLoggedIn(true);
        await settings.setRole(data['role']);
        if (data['role'] == 'technician') {
          await settings.setAssignedTechnician(data['technician_name']);
        }
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CallListScreen()),
          );
        }
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Login failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClayContainer(
                  color: baseColor,
                  height: 100,
                  width: 100,
                  borderRadius: 50,
                  depth: 20,
                  child: const Icon(Icons.grid_on, size: 50, color: Colors.blueAccent),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Grid CRM',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Admin'),
                      selected: _isAdmin,
                      onSelected: (val) => setState(() => _isAdmin = true),
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Technician'),
                      selected: !_isAdmin,
                      onSelected: (val) => setState(() => _isAdmin = false),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                if (_isAdmin) ...[
                  ClayContainer(
                    color: baseColor,
                    borderRadius: 12,
                    depth: -10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Username',
                          icon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClayContainer(
                    color: baseColor,
                    borderRadius: 12,
                    depth: -10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Password',
                          icon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  ClayContainer(
                    color: baseColor,
                    borderRadius: 12,
                    depth: -10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Technician Name',
                          icon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClayContainer(
                    color: baseColor,
                    borderRadius: 12,
                    depth: -10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '4-digit PIN',
                          icon: Icon(Icons.pin_outlined),
                        ),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : GestureDetector(
                        onTap: _login,
                        child: ClayContainer(
                          color: Colors.blueAccent,
                          borderRadius: 12,
                          depth: 20,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            child: Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

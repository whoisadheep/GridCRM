import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';
import '../../core/settings.dart';

class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({super.key});

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isLoading = false;
  String _message = "How can I help you?";
  
  @override
  void initState() {
    super.initState();
    _initSpeech();
  }
  
  void _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }
  
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _sendCommand(); // automatically send after stopping
    }
  }

  Future<void> _sendCommand() async {
    if (_controller.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _message = "Processing...";
    });
    
    try {
      final settings = SettingsService();
      final baseUrl = await settings.getBaseUrl();
      
      final response = await http.post(
        Uri.parse('$baseUrl/assistant'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': _controller.text}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _message = data['message'] ?? "Command successful!";
          _controller.clear();
        });
        // Auto-reloaded by stream
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _message = "Error: ${data['error'] ?? 'Failed to execute'}";
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error: Could not connect to assistant.";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
        top: 20,
        left: 20,
        right: 20
      ),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10)
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(
                "AI Assistant",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _message,
            style: TextStyle(
              fontSize: 16,
              color: _message.startsWith("Error") ? Colors.red : Colors.green[700],
              fontWeight: FontWeight.w500
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClayContainer(
                  color: baseColor,
                  depth: -10,
                  borderRadius: 20,
                  emboss: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "E.g. 'resolve alice call'",
                      ),
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _listen,
                child: ClayContainer(
                  color: _isListening ? Colors.redAccent : baseColor,
                  depth: _isListening ? -10 : 20,
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isLoading ? null : _sendCommand,
                child: ClayContainer(
                  color: Colors.blueAccent,
                  depth: 20,
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                  child: _isLoading 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

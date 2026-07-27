import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';
import 'confirm_screen.dart';

class QuickCreateScreen extends ConsumerStatefulWidget {
  const QuickCreateScreen({super.key});

  @override
  ConsumerState<QuickCreateScreen> createState() => _QuickCreateScreenState();
}

class _QuickCreateScreenState extends ConsumerState<QuickCreateScreen> {
  final _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isLoading = false;

  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        _previousText = _textController.text;
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textController.text = '${_previousText} ${val.recognizedWords}'.trim();
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _submitAI() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final syncService = ref.read(syncServiceProvider);

    setState(() => _isLoading = true);
    final extracted = await syncService.extractCallInfo(text);
    setState(() => _isLoading = false);

    if (mounted) {
      if (extracted != null) {
        extracted['raw_input'] = text;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ConfirmScreen(initialData: extracted)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to extract. Enter manually.')),
        );
        _submitManual();
      }
    }
  }

  void _submitManual() {
    final text = _textController.text.trim();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ConfirmScreen(
        initialData: {'problem_description': text, 'raw_input': text}
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Service Call', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          children: [
            const Text(
              "Describe the issue below, or tap the mic to speak.",
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClayContainer(
                color: baseColor,
                borderRadius: 24,
                depth: -20,
                emboss: true,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.withOpacity(0.05),
                        Colors.purple.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'e.g. "Customer Parle G needs an AC repair urgently, assign to John..."',
                      hintStyle: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading)
              Column(
                children: [
                  GestureDetector(
                    onTap: _listen,
                    child: ClayContainer(
                      color: _isListening ? Colors.redAccent : const Color(0xFF4285F4),
                      height: 80,
                      width: 80,
                      borderRadius: 40,
                      depth: _isListening ? -20 : 30, // Emboss when listening
                      curveType: _isListening ? CurveType.concave : CurveType.convex,
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Magical AI Button
                      Expanded(
                        child: GestureDetector(
                          onTap: _submitAI,
                          child: ClayContainer(
                            color: baseColor,
                            height: 60,
                            borderRadius: 30,
                            depth: 20,
                            curveType: CurveType.convex,
                            color: const Color(0xFF9C27B0),
                            height: 60,
                            borderRadius: 30,
                            depth: 20,
                            curveType: CurveType.convex,
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Magic',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Manual Button
                      Expanded(
                        child: GestureDetector(
                          onTap: _submitManual,
                          child: ClayContainer(
                            color: baseColor,
                            height: 60,
                            borderRadius: 30,
                            depth: 20,
                            curveType: CurveType.convex,
                            child: const Center(
                              child: Text(
                                'Manual',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
              ],
            ),
          ),
        ),
      );
  }
}

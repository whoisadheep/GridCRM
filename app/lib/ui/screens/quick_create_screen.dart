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
      appBar: AppBar(title: const Text('Quick Create', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          children: [
            Expanded(
              child: ClayContainer(
                color: baseColor,
                borderRadius: 24,
                depth: 20,
                emboss: true,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: 'Describe the issue...',
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
                      color: _isListening ? Colors.redAccent : baseColor,
                      height: 80,
                      width: 80,
                      borderRadius: 40,
                      depth: _isListening ? -20 : 30, // Emboss when listening
                      curveType: _isListening ? CurveType.concave : CurveType.convex,
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 40,
                        color: _isListening ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                            surfaceColor: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [Colors.deepPurpleAccent, Colors.blueAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Magic',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
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
                            depth: 15,
                            curveType: CurveType.convex,
                            child: const Center(
                              child: Text(
                                'Manual',
                                style: TextStyle(
                                  color: Colors.black54,
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

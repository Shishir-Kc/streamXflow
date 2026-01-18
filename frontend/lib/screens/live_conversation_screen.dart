import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

class LiveConversationScreen extends StatefulWidget {
  const LiveConversationScreen({super.key});

  @override
  State<LiveConversationScreen> createState() => _LiveConversationScreenState();
}

class _LiveConversationScreenState extends State<LiveConversationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  
  // Audio State
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final BytesBuilder _audioBuffer = BytesBuilder();
  Process? _linuxRecordingProcess;
  StreamSubscription<List<int>>? _recordSubscription;
  Timer? _silenceTimer;
  bool _hasSpeechStarted = false;

  @override
  void initState() {
    super.initState();
    // Simulate audio reactivity with a breathing animation
    _breathingController = AnimationController(
       duration: const Duration(seconds: 2),
       vsync: this,
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut)
    );

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        _breathingController.duration = const Duration(seconds: 2);
        _breathingController.repeat(reverse: true);
        
        // Auto-resume listening loop
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startRecording();
        });
      }
    });

    // Auto-start recording on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _silenceTimer?.cancel();
    _recordSubscription?.cancel();
    _linuxRecordingProcess?.kill();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _processAudioChunk(List<int> data) {
    if (!_isListening) return;
    
    int maxVal = 0;
    for (int i = 0; i < data.length - 1; i += 2) {
      if (i + 1 >= data.length) break;
      int val = (data[i + 1] << 8) | data[i];
      if (val > 32767) val -= 65536;
      if (val.abs() > maxVal) maxVal = val.abs();
    }

    // Robust Threshold: 8000 (Ignores loud snaps/noise, requires voice)
    if (maxVal > 8000) { 
      _hasSpeechStarted = true;
      _silenceTimer?.cancel();
      _silenceTimer = null;
    } else {
      // Only trigger disconnect if speech was actually started
      if (_hasSpeechStarted && _silenceTimer == null) {
        _silenceTimer = Timer(const Duration(milliseconds: 1200), () {
          _stopRecording();
        });
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isProcessing || _isPlaying) return;

    if (_isListening) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      _audioBuffer.clear();
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _hasSpeechStarted = false; // Reset speech flag
      
      if (Platform.isLinux) {
         try {
           _linuxRecordingProcess = await Process.start('arecord', [
             '--format=S16_LE',
             '--rate=44100',
             '--channels=1',
             '--file-type=raw',
             '-', 
           ]);
           
           _linuxRecordingProcess!.stdout.listen((data) {
             _audioBuffer.add(data);
             _processAudioChunk(data);
           });
           
           setState(() => _isListening = true);
           return;
         } catch (e) {
            debugPrint("Linux record failed: $e");
         }
      }

      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 44100,
            numChannels: 1,
          )
        );

        _recordSubscription = stream.listen((data) {
          _audioBuffer.add(data);
          _processAudioChunk(data);
        });

        setState(() {
          _isListening = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    
    if (Platform.isLinux) {
      _linuxRecordingProcess?.kill();
      _linuxRecordingProcess = null;
    } else {
      await _audioRecorder.stop();
      await _recordSubscription?.cancel();
    }
    
    if (!_isListening) return; // Already stopped?
    
    setState(() {
      _isListening = false;
      _isProcessing = true;
    });

    final rawBytes = _audioBuffer.toBytes();
    if (rawBytes.isNotEmpty) {
      try {
        final wavHeader = _buildWavHeader(rawBytes.length);
        final wavBytes = Uint8List.fromList(wavHeader + rawBytes);
        await _sendAudioToBackend(wavBytes);
      } catch (e) {
        debugPrint("Error processing audio: $e");
        setState(() => _isProcessing = false);
      }
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendAudioToBackend(Uint8List audioBytes) async {
    try {
      final uri = Uri.parse('http://127.0.0.1:8000/v1/live/conv/');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          audioBytes,
          filename: 'audio.wav',
        )
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final audioData = response.bodyBytes;
        await _playAudioResponse(audioData);
      } else {
        debugPrint("Backend error: ${response.statusCode} - ${response.body}");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint("Network error: $e");
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _playAudioResponse(Uint8List bytes) async {
    setState(() {
      _isProcessing = false;
      _isPlaying = true;
    });
    
    // Speed up animation for playback
    _breathingController.duration = const Duration(milliseconds: 400);
    _breathingController.repeat(reverse: true);
    
    try {
      await _audioPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint("Playback error: $e");
      setState(() => _isPlaying = false);
      _breathingController.duration = const Duration(seconds: 2);
      _breathingController.repeat(reverse: true);
    }
  }

  // --- Helper: WAV Header Construction ---
  Uint8List _buildWavHeader(int dataLength) {
    final int sampleRate = 44100;
    final int numChannels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int totalDataLen = dataLength + 36;

    final header = BytesBuilder();
    header.add('RIFF'.codeUnits);
    header.add(_intToBytes(totalDataLen, 4));
    header.add('WAVE'.codeUnits);
    header.add('fmt '.codeUnits);
    header.add(_intToBytes(16, 4));
    header.add(_intToBytes(1, 2));
    header.add(_intToBytes(numChannels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(bitsPerSample, 2));
    header.add('data'.codeUnits);
    header.add(_intToBytes(dataLength, 4));
    return header.toBytes();
  }

  List<int> _intToBytes(int value, int length) {
    final bytes = <int>[];
    for (var i = 0; i < length; i++) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic gradient opacity based on state
    double spread = 0.3;
    if (_isListening) spread = 0.6; // Wider when listening
    if (_isPlaying) spread = 0.8; // Widest when playing
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                double val = _breathingAnimation.value;
                if (_isListening) val = 0.8 + (val * 0.2); // Pulse harder
                
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        (_isListening ? Colors.redAccent : (_isPlaying ? Colors.greenAccent : Colors.blueAccent)).withOpacity(val),
                        const Color(0xFF6B4DFF).withOpacity(val * 0.5),
                        Colors.black.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                 if (_isProcessing)
                   const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.blueAccent),
                 
                 const Spacer(),
                 
                 // Bottom Controls
                 Padding(
                   padding: const EdgeInsets.only(bottom: 40.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       // Mic Button
                       GestureDetector(
                         onTap: _toggleListening,
                         child: Container(
                           height: 64, width: 64,
                           decoration: BoxDecoration(
                             color: _isListening ? Colors.white : Colors.white10,
                             shape: BoxShape.circle,
                           ),
                           child: Icon(
                             _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                             color: _isListening ? Colors.black : Colors.white,
                             size: 32,
                           ),
                         ),
                       ),
                       
                       const SizedBox(width: 48),

                       // End Call Button
                       GestureDetector(
                         onTap: () => Navigator.of(context).pop(),
                         child: Container(
                           height: 64, width: 64,
                           decoration: BoxDecoration(
                             color: Colors.redAccent,
                             shape: BoxShape.circle,
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.redAccent.withOpacity(0.4),
                                 blurRadius: 16,
                                 spreadRadius: 2,
                               )
                             ]
                           ),
                           child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                         ),
                       ),
                     ],
                   ),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAction({required IconData icon, required VoidCallback onTap}) {
    return Container(
      height: 50, width: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}

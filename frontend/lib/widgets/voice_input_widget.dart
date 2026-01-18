import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

class VoiceInputWidget extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(Uint8List audioData) onCompleted;

  const VoiceInputWidget({
    super.key,
    required this.onCancel,
    required this.onCompleted,
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget> with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _amplitudeTimer;
  final int _barCount = 80;
  List<double> _amplitudes = [];
  bool _isRecording = false;
  
  // In-memory audio buffer
  final BytesBuilder _audioData = BytesBuilder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  @override
  void initState() {
    super.initState();
    _amplitudes = List.filled(_barCount, 5.0, growable: true);
    _startRecording();
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Linux fallback variables
  Process? _linuxRecordingProcess;

  Future<void> _startRecording() async {
    _audioData.clear(); // Clear previous data
    
    try {
      if (Platform.isLinux) {
         try {
           if (await _audioRecorder.hasPermission()) {
             // Try standard streaming first
             final stream = await _audioRecorder.startStream(
               const RecordConfig(
                 encoder: AudioEncoder.pcm16bits, 
                 sampleRate: 44100, 
                 numChannels: 1
               )
             );
             
             _audioStreamSubscription = stream.listen((data) {
               _audioData.add(data);
               // Amplitude calc
               _processAudioChunk(data);
             });

             setState(() => _isRecording = true);
             return;
           }
         } catch (e) {
           debugPrint("Standard record failed, trying Linux fallback: $e");
           await _startLinuxRecording();
           return;
         }
      }

      // Non-Linux or Standard success path
      if (await _audioRecorder.hasPermission()) {
         final stream = await _audioRecorder.startStream(
           const RecordConfig(
             encoder: AudioEncoder.pcm16bits, 
             sampleRate: 44100, 
             numChannels: 1
           )
         );
         
         _audioStreamSubscription = stream.listen((data) {
           _audioData.add(data);
           _processAudioChunk(data);
         });
        
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _startLinuxRecording() async {
    try {
      // Start arecord: raw PCM, Signed 16-bit Little Endian, 44100Hz, Mono, to stdout (-)
      _linuxRecordingProcess = await Process.start('arecord', [
        '-t', 'raw', 
        '-f', 'S16_LE', 
        '-r', '44100', 
        '-c', '1', 
        '-' 
      ]);

      setState(() => _isRecording = true);

      // Listen to stdout 
      _linuxRecordingProcess!.stdout.listen((data) {
        _audioData.add(data);
        _processAudioChunk(data);
      });
      
      debugPrint("Started Linux arecord process");

    } catch (e) {
      debugPrint("Linux fallback failed: $e");
    }
  }

  void _processAudioChunk(List<int> data) {
    if (data.isEmpty) return;
    
    // Calculate RMS or Max amplitude from chunk
    // S16_LE: combine 2 bytes.
    int maxVal = 0;
    // Inspect a subset of samples to save CPU
    int step = 2; // Check every sample
    if (data.length > 1000) step = 10;

    for (int i = 0; i < data.length - 1; i += step * 2) {
      // Little Endian
      int byte1 = data[i];
      int byte2 = data[i + 1];
      
      int sample = (byte2 << 8) | byte1;
      if (sample > 32767) sample -= 65536; 
      
      if (sample.abs() > maxVal) {
        maxVal = sample.abs();
      }
    }
    
    // Boost sensitivity: use 12000 instead of 32768
    double normalized = (maxVal / 12000.0).clamp(0.0, 1.0);
    
    if (normalized < 0.05) normalized = 0.02; 
    double height = 5.0 + (normalized * 50.0);
    
    if (mounted) {
       setState(() {
        _amplitudes.removeAt(0);
        _amplitudes.add(height);
      });
    }
  }

  // Amplitude polling is no longer needed as we calculate from stream
  Future<void> _updateAmplitude() async {}

  Future<void> _stopRecording(bool send) async {
    _audioStreamSubscription?.cancel();
    
    if (_linuxRecordingProcess != null) {
      _linuxRecordingProcess?.kill();
      _linuxRecordingProcess = null;
    } else {
      try {
        await _audioRecorder.stop();
      } catch (e) {
        debugPrint("Error stopping: $e");
      }
    }
    
    setState(() => _isRecording = false);

    if (send) {
      // Construct WAV
      final rawBytes = _audioData.toBytes();
      if (rawBytes.isNotEmpty) {
        final wavHeader = _buildWavHeader(rawBytes.length);
        final wavBytes = Uint8List.fromList(wavHeader + rawBytes);
        widget.onCompleted(wavBytes);
      } else {
        widget.onCancel();
      }
    } else {
      widget.onCancel();
    }
    
    _audioData.clear();
  }
  
  Uint8List _buildWavHeader(int dataLength) {
    final int sampleRate = 44100;
    final int numChannels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int totalDataLen = dataLength + 36;

    final header = BytesBuilder();
    
    // RIFF chunk
    header.add('RIFF'.codeUnits);
    header.add(_intToBytes(totalDataLen, 4)); // File size - 8
    header.add('WAVE'.codeUnits);
    
    // fmt chunk
    header.add('fmt '.codeUnits);
    header.add(_intToBytes(16, 4)); // Chunk size
    header.add(_intToBytes(1, 2)); // Audio format (1 = PCM)
    header.add(_intToBytes(numChannels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(bitsPerSample, 2));
    
    // data chunk
    header.add('data'.codeUnits);
    header.add(_intToBytes(dataLength, 4));
    
    return header.toBytes();
  }
  
  List<int> _intToBytes(int value, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D), 
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.add, color: Colors.white54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // Waveform
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              crossAxisAlignment: CrossAxisAlignment.center, 
              children: [
                ..._amplitudes.map((height) {
                  return Flexible( 
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1), 
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80), 
                        curve: Curves.easeOutQuad,
                        width: 4, 
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _stopRecording(false),
            icon: const Icon(Icons.close, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
           IconButton(
            onPressed: () => _stopRecording(true),
            icon: const Icon(Icons.check, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

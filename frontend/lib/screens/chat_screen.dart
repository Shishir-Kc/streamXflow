import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/model_selector_modal.dart';
import '../widgets/voice_input_widget.dart';
import 'live_conversation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late FocusNode _focusNode;
  bool _isTyping = false;
  bool _isRecording = false;
  String _selectedModel = 'krypton';
  String _currentGreeting = "";
  bool _showCopyNotification = false;

  final List<String> _greetings = [
    "Hi, what are we planning today?",
    "Ready to build something amazing?",
    "What's on your mind?",
    "Let's solve some problems.",
    "Hello! How can I help you?",
    "Krypton is ready for you.",
    "What can I do for you today?",
  ];

  @override
  void initState() {
    super.initState();
    _setRandomGreeting();
    _focusNode = FocusNode(onKeyEvent: (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.enter && HardwareKeyboard.instance.isControlPressed) {
        if (event is KeyDownEvent) {
          _handleSubmitted(_textController.text);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyO && 
          HardwareKeyboard.instance.isControlPressed && 
          HardwareKeyboard.instance.isShiftPressed) {
        if (event is KeyDownEvent) {
          _clearChat();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _isTyping = false;
      _setRandomGreeting();
    });
  }

  void _setRandomGreeting() {
    setState(() {
      _currentGreeting = _greetings[Random().nextInt(_greetings.length)];
    });
  }

  void _handleSubmitted(String text) {
    if (_isTyping || text.trim().isEmpty) return;
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });

    _scrollToBottom();

    _scrollToBottom();

    _fetchResponse(text);
  }



  Future<void> _fetchResponse(String message) async {
    // API Endpoint based on selected model
    String endpoint = 'http://127.0.0.1:8000/v1/chat/krypton/';
    if (_selectedModel == 'krypton_agent') {
      endpoint = 'http://127.0.0.1:8000/v1/chat/krypton/agent/';
    } else if (_selectedModel == 'chatGpt') {
      endpoint = 'http://127.0.0.1:8000/v1/chat/gpt/';
    } else if (_selectedModel == 'gemini') {
      endpoint = 'http://127.0.0.1:8000/v1/chat/gemini/3/flash/preview/';
    }
    final url = Uri.parse(endpoint);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'chat': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Expecting { "reply": "Hello..." }
        if (data['reply'] != null) {
           final replyText = data['reply'].toString();
           _addBotMessage(replyText);
        } else {
           _addBotMessage("Received empty or invalid response from AI.");
        }
      } else {
        _addBotMessage("Error: Failed to connect to AI (Status ${response.statusCode})");
      }
    } catch (e) {
      _addBotMessage("Error: Could not connect to API. Is the server running?");
    }
  }

  void _addBotMessage(String text) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: text,
            isUser: false,
          ));
        });
        _scrollToBottom();
      }
  }

  bool _isTranscribing = false;

  Future<void> _transcribeAudio(Uint8List audioBytes) async {
    setState(() {
      _isTranscribing = true;
    });

    try {
      final uri = Uri.parse('http://127.0.0.1:8000/v1/transcribe/');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          audioBytes,
          filename: 'audio.wav', // Filename needed for backend to detect type extension
        )
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['text'] != null) {
          setState(() {
            _textController.text = data['text'];
          });
        }
      } else {
        debugPrint("Transcription failed: ${response.statusCode} - ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transcription failed: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint("Transcription error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error transcribing audio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }


  void _showCopiedNotification() {
    setState(() {
      _showCopyNotification = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showCopyNotification = false;
        });
      }
    });
  }

  Widget _buildMessageItem(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Added horizontal padding for cleaner look
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85), // Increased max width slightly
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFF2D2D2D)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: message.isUser ? null : Border.all(color: Colors.white10),
            ),
            child: message.isUser
                ? Text(
                    message.text,
                    style: GoogleFonts.inter(color: Colors.white),
                  )
                : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: MarkdownGenerator().buildWidgets(
                        message.text,
                        config: MarkdownConfig(
                          configs: [
                            const PConfig(
                              textStyle: TextStyle(
                                  color: Colors.white70, fontFamily: 'Inter'),
                            ),
                            PreConfig(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                              wrapper: (child, code, language) => Stack(
                                children: [
                                  child,
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: InkWell(
                                      onTap: () {
                                        Clipboard.setData(
                                            ClipboardData(text: code));
                                        _showCopiedNotification();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.copy_rounded,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
          const SizedBox(height: 4),
          _buildCopyButton(message.text),
        ],
      ),
    );
  }

  Widget _buildCopyButton(String text) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        _showCopiedNotification();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.copy_rounded,
          color: Colors.white38,
          size: 14,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: AnimatedOpacity(
                    opacity: _messages.isEmpty ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    child: Text(
                      _currentGreeting,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.1],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                         return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: TypingIndicator(),
                          ),
                        );
                      }
                      
                      final message = _messages[index];
                      return _buildMessageItem(message);
                    },
                  ),
                ),
                // Copied Notification
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _showCopyNotification ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Copied to clipboard',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            child: _isRecording 
              ? VoiceInputWidget(
                  onCancel: () {
                    setState(() {
                      _isRecording = false;
                    });
                  },
                onCompleted: (audioBytes) {
                    setState(() {
                      _isRecording = false;
                    });
                    debugPrint("Voice recording completed. Bytes: ${audioBytes.length}");
                    _transcribeAudio(audioBytes);
                  },
                )
              : Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onSubmitted: _handleSubmitted,
                    onChanged: (val) {
                      setState(() {});
                    },
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_isTranscribing,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: _isTranscribing ? 'Transcribing audio...' : 'Ask anything...',
                      hintStyle: TextStyle(
                        color: _isTranscribing 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.onSurfaceVariant
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      suffix: _isTranscribing 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            ) 
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.black54,
                            builder: (context) => ModelSelectorModal(
                              onModelSelected: (modelId) {
                                setState(() {
                                  _selectedModel = modelId;
                                });
                              },
                            ),
                          );
                        },
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedModel,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showToolsMenu(context),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                        color: Colors.white70,
                        tooltip: 'Tools',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _isTyping ? null : () {
                          setState(() {
                            _isRecording = true;
                          });
                        },
                        icon: const Icon(Icons.mic_rounded, size: 24),
                        color: Colors.white70,
                        disabledColor: Colors.white24,
                        tooltip: 'Voice Input Mode',
                      ),
                      const SizedBox(width: 8),
                      // Toggle between Live Conversation and Send Button
                      if (_textController.text.trim().isEmpty)
                        Container(
                          height: 36,
                          width: 36,
                          decoration: const BoxDecoration(
                            color: Colors.black, // or Color(0xFF1E1E1E) for consistency
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _isTyping ? null : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const LiveConversationScreen(),
                                ),
                              );
                            },
                            icon: Icon(Icons.graphic_eq, size: 20, color: _isTyping ? Colors.white38 : Colors.white),
                            padding: EdgeInsets.zero,
                            tooltip: 'Live Conversation',
                          ),
                        )
                      else
                        IconButton.filled(
                          onPressed: _isTyping ? null : () => _handleSubmitted(_textController.text),
                          icon: _isTyping 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)) 
                              : const Icon(Icons.arrow_upward_rounded, size: 20),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          style: IconButton.styleFrom(
                             backgroundColor: Theme.of(context).colorScheme.primary,
                             foregroundColor: Theme.of(context).colorScheme.onPrimary,
                             disabledBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                             padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToolsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text('Tools', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            _buildToolOption(
              icon: Icons.image_rounded,
              label: 'Generate Image',
              description: 'Create AI art from text',
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Image Gen
              },
            ),
            const SizedBox(height: 12),
            _buildToolOption(
              icon: Icons.code_rounded,
              label: 'Generate Code',
              description: 'Write snippets or functions',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(context);
                 // TODO: Implement Code Gen
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildToolOption({required IconData icon, required String label, required String description, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }

}

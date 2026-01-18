class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isThinking;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isThinking = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

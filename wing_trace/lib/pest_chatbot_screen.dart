import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class PestChatbotScreen extends StatefulWidget {
  const PestChatbotScreen({super.key});

  @override
  State<PestChatbotScreen> createState() => _PestChatbotScreenState();
}

class _PestChatbotScreenState extends State<PestChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "bot", "text": "Hello! I am your WingTrace Assistant. Ask me anything about pests, or select a quick question below."}
  ];
  bool _isLoading = false;

  // --- 1. CONFIGURATION ---
  // PRO TIP: In a real app, don't hardcode this. Use a .env file or Firebase Remote Config.
  static const String _apiKey = String.fromEnvironment('API_KEY');

  late final GenerativeModel _model;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    // Safety check: Alert yourself if the key wasn't loaded
    if (_apiKey.isEmpty) {
      debugPrint("WARNING: API Key is empty. Did you run with --dart-define-from-file?");
    }
    
    // Initialize Gemini with a "System Instruction" to keep it on topic
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system("You are a pest control expert for the WingTrace app. "
          "Provide concise, scientific, and helpful advice about mosquitoes and agricultural pests. "
          "If the user asks about something unrelated to pests or the app, politely redirect them."),
    );
    _chat = _model.startChat();
  }

  // --- 2. SEND LOGIC ---
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await _chat.sendMessage(Content.text(text));
      setState(() {
        _messages.add({"role": "bot", "text": response.text ?? "I couldn't process that."});
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "Error: Check your API key or connection."});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pest Assistant")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg['role'] == 'user';
                return _buildChatBubble(msg['text']!, isUser);
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator(color: Colors.green)),
          _buildQuickActions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.green : Colors.grey[300],
          borderRadius: BorderRadius.circular(15).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(15),
            bottomLeft: isUser ? const Radius.circular(15) : const Radius.circular(0),
          ),
        ),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildQuickActions() {
    final questions = ["Prevent Aedes?", "Dengue symptoms?", "Best repellents?"];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: questions.map((q) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ActionChip(
            label: Text(q, style: const TextStyle(fontSize: 12)),
            onPressed: () => _sendMessage(q),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: "Type your question...", border: InputBorder.none),
              onSubmitted: _sendMessage,
            ),
          ),
          IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: () => _sendMessage(_controller.text)),
        ],
      ),
    );
  }
}
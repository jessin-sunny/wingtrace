import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Use http instead of google_generative_ai
import 'dart:convert';

class PestChatbotScreen extends StatefulWidget {
  const PestChatbotScreen({super.key});

  @override
  State<PestChatbotScreen> createState() => _PestChatbotScreenState();
}

class _PestChatbotScreenState extends State<PestChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "bot", "text": "Hello! I am Tracy, your WingTrace Assistant. Ask me anything about pests, or select a quick question below."}
  ];
  bool _isLoading = false;

  // --- CONFIGURATION ---
  // Ensure you use your GROQ API KEY here
  static const String _apiKey = String.fromEnvironment('API_KEY');
  static const String _baseUrl = "https://api.groq.com/openai/v1/chat/completions";

  // --- SEND LOGIC (GROQ COMPATIBLE) ---
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey', // Standard Groq Auth
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant", // Your desired model
          "messages": [
            {
              "role": "system", 
              "content": "You are Tracy, a pest control expert for the WingTrace app. "
                         "Provide concise, scientific advice about pests."
            },
            ..._messages.map((m) => {
              "role": m['role'] == 'user' ? 'user' : 'assistant',
              "content": m['text']
            }).toList(),
            {"role": "user", "content": text}
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data['choices'][0]['message']['content']; // Parse response
        
        setState(() {
          _messages.add({"role": "bot", "text": botResponse});
        });
      } else {
        throw Exception("Failed to connect to Groq: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "Error: Check your Groq API key or connection."});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI REMAINS THE SAME ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("TRACY - Assistant"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20), 
              child: LinearProgressIndicator(color: Colors.green, backgroundColor: Colors.transparent)
            ),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuickActions(),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildQuickActions() {
    final questions = ["Prevent Aedes?", "Dengue symptoms?", "Best repellents?"];
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: questions.map((q) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            label: Text(q, style: const TextStyle(fontSize: 12, color: Colors.green)),
            onPressed: () => _sendMessage(q),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: "Ask Tracy...", border: InputBorder.none),
              onSubmitted: _sendMessage,
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.green,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(_controller.text),
            ),
          ),
        ],
      ),
    );
  }
}
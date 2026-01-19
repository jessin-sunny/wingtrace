import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PestChatbotScreen extends StatefulWidget {
  const PestChatbotScreen({super.key});

  @override
  State<PestChatbotScreen> createState() => _PestChatbotScreenState();
}

class _PestChatbotScreenState extends State<PestChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // --- CONFIGURATION ---
  // Note: For production, use environment variables or a secure vault.
  static const String _apiKey = String.fromEnvironment('API_KEY');
  static const String _baseUrl = "https://api.groq.com/openai/v1/chat/completions";

  // Save Messages to Firebase Firestore
  Future<void> _saveToFirebase(String role, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .add({
      "role": role,
      "text": text,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  // --- SEND LOGIC (GROQ COMPATIBLE) ---
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _controller.clear();
    setState(() => _isLoading = true);

    try {
      // 1. Save User Message immediately to local Firebase
      await _saveToFirebase("user", text);

      // 2. Fetch last 6 messages for GROQ memory context
      final historySnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .orderBy('timestamp', descending: true)
          .limit(6)
          .get();

      // Reverse so messages are in chronological order for the AI
      final history = historySnap.docs.reversed.map((doc) => {
        "role": doc['role'] == 'user' ? 'user' : 'assistant',
        "content": doc['text']
      }).toList();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {"role": "system", "content": "You are Tracy, a pest control expert for the WingTrace app."},
            ...history
          ],
        }),
      );

      if (response.statusCode == 200) {
        final botResponse = jsonDecode(response.body)['choices'][0]['message']['content'];
        await _saveToFirebase("bot", botResponse);
      }
    } catch (e) {
      debugPrint("Chat Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _deleteChatHistory() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Get all documents in the 'chats' sub-collection
      final chatCollection = _firestore
          .collection('users')
          .doc(uid)
          .collection('chats');
      
      final snapshots = await chatCollection.get();

      // 2. Initialize a WriteBatch
      WriteBatch batch = _firestore.batch();

      // 3. Add each document's deletion to the batch
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      // 4. Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chat history cleared.")),
        );
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to clear chat.")),
        );
      }
    }
  }
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat?"),
        content: const Text("This will permanently delete all your messages with Tracy."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              _deleteChatHistory();
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid; // Fixed: uid must be defined in build

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("TRACY - Assistant"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: uid == null 
              ? const Center(child: Text("Please login to chat."))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(uid)
                      .collection('chats')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Something went wrong"));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true, // Newer messages at the bottom
                      padding: const EdgeInsets.all(15),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildChatBubble(data['text'] ?? "", data['role'] == 'user');
                      },
                    );
                  },
                ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Colors.green, backgroundColor: Colors.transparent),
          _buildQuickActions(), // Integrated correctly
          _buildInputArea(),
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
    return SizedBox(
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
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: "Ask Tracy...", border: InputBorder.none),
                onSubmitted: (val) => _sendMessage(val),
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
      ),
    );
  }
}
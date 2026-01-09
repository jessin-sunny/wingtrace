import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBE7),
      appBar: AppBar(
        title: const Text("Pest Analytics"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Weekly Detection Trends", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 20),
            
            // Simple Custom Bar Chart
            Container(
              height: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBar("Mon", 0.4),
                  _buildBar("Tue", 0.7),
                  _buildBar("Wed", 0.9),
                  _buildBar("Thu", 0.5),
                  _buildBar("Fri", 0.8),
                  _buildBar("Sat", 0.3),
                  _buildBar("Sun", 0.6),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text("Pest Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            _buildStatTile("Aedes Aegypti", "45%", Colors.red),
            _buildStatTile("Anopheles", "30%", Colors.orange),
            _buildStatTile("Other Pests", "25%", Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(String day, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 150 * heightFactor,
          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(height: 5),
        Text(day, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildStatTile(String name, String percentage, Color color) {
    return ListTile(
      leading: Icon(Icons.pie_chart, color: color),
      title: Text(name),
      trailing: Text(percentage, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
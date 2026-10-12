import 'package:flutter/material.dart';
import 'prediction_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> matches = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await PredictionService.getMatches();
    setState(() {
      matches = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bothie Predictions")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final m = matches[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${m['home']} vs ${m['away']}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Safety: ${m['safety'].toStringAsFixed(0)}%"),
                        const SizedBox(height: 6),
                        ...List.generate(m['predictions'].length, (i) {
                          final p = m['predictions'][i];
                          return Text(
                              "${i + 1}️⃣ ${p['label']} — ${p['confidence'].toStringAsFixed(0)}%");
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

}

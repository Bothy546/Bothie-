import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionService {
  static const String apiKey = "e0386235-ab5d-4380-9b1e-869de068429a";
  static const String baseUrl = "https://api.oddspapi.io/v1";

  static Future<List<Map<String, dynamic>>> getMatches() async {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    final url = Uri.parse(
      "$baseUrl/fixtures?sport=football&from=${_fmt(today)}&to=${_fmt(tomorrow)}&apikey=$apiKey",
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    List fixtures = data['fixtures'] ?? [];

    List<Map<String, dynamic>> results = [];

    for (var match in fixtures) {
      final predictions = _calculatePredictions(match);
      final safety = _calculateSafety(predictions);

      results.add({
        "home": match['home_team'],
        "away": match['away_team'],
        "time": match['start_time'],
        "predictions": predictions,
        "safety": safety,
      });
    }

    // Sort by safety (safest first)
    results.sort((a, b) => b['safety'].compareTo(a['safety']));
    return results;
  }

  static String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static List<Map<String, dynamic>> _calculatePredictions(match) {
    List<Map<String, dynamic>> markets = [];
    final odds = match['odds'] ?? {};

    void addMarket(String label, double? price) {
      if (price != null && price > 1.0) {
        double confidence = (1 / price) * 100;
        markets.add({"label": label, "confidence": confidence});
      }
    }

    addMarket("Match Result: Home Win", odds['home_win']);
    addMarket("Match Result: Draw", odds['draw']);
    addMarket("Match Result: Away Win", odds['away_win']);
    addMarket("BTTS: Yes", odds['btts_yes']);
    addMarket("BTTS: No", odds['btts_no']);
    addMarket("Over 2.5 Goals", odds['over_2_5']);
    addMarket("Under 2.5 Goals", odds['under_2_5']);
    addMarket("First Half Result: Home Lead", odds['ht_home']);
    addMarket("First Half Result: Draw", odds['ht_draw']);
    addMarket("First Half Result: Away Lead", odds['ht_away']);

    markets.sort((a, b) => b['confidence'].compareTo(a['confidence']));

    // Remove conflicting markets, keep top 4
    List<Map<String, dynamic>> finalPicks = [];
    Set<String> usedGroups = {};

    for (var m in markets) {
      String group = m['label'].toString().split(":")[0];
      if (!usedGroups.contains(group)) {
        finalPicks.add(m);
        usedGroups.add(group);
      }
      if (finalPicks.length == 4) break;
    }

    return finalPicks;
  }

  static double _calculateSafety(List<Map<String, dynamic>> predictions) {
    if (predictions.isEmpty) return 0;
    double total = 0;
    for (var p in predictions) {
      total += p['confidence'];
    }
    return total / predictions.length;
  }

}

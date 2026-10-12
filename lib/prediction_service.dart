import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionService {
  static const String apiKey = "1a53deaf-aa03-404f-935a-a2a2c3e99211";
  static const String baseUrl = "https://api.oddspapi.io/v4";

  static Future<List<Map<String, dynamic>>> getMatches() async {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    final fixturesUrl = Uri.parse(
      "$baseUrl/fixtures?apiKey=$apiKey&sportId=10&from=${_fmt(today)}&to=${_fmt(tomorrow)}&hasOdds=true",
    );
    final fixturesRes = await http.get(fixturesUrl).timeout(const Duration(seconds: 10));
    if (fixturesRes.statusCode != 200) {
      throw Exception("Fixtures error: ${fixturesRes.statusCode} - ${fixturesRes.body}");
    }

    List fixtures = jsonDecode(fixturesRes.body);
    fixtures = fixtures.take(5).toList(); // lowered to 5 for free tier safety

    List<Map<String, dynamic>> results = [];

    // Fetch ONE at a time, with a short delay (avoids free-tier rate limiting)
    for (var fx in fixtures) {
      final match = await _fetchMatchOdds(fx);
      if (match != null) results.add(match);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    results.sort((a, b) => b['safety'].compareTo(a['safety']));
    return results;
  }

  static Future<Map<String, dynamic>?> _fetchMatchOdds(fx) async {
    try {
      final fixtureId = fx['fixtureId'];
      final home = fx['participant1Name'] ?? 'Home';
      final away = fx['participant2Name'] ?? 'Away';

      final oddsUrl = Uri.parse("$baseUrl/odds?apiKey=$apiKey&fixtureId=$fixtureId");
      final oddsRes = await http.get(oddsUrl).timeout(const Duration(seconds: 10));
      if (oddsRes.statusCode != 200) return null;

      final oddsData = jsonDecode(oddsRes.body);
      final bookmakerOdds = oddsData['bookmakerOdds'] as Map<String, dynamic>?;
      if (bookmakerOdds == null || bookmakerOdds.isEmpty) return null;

      final firstBookie = bookmakerOdds.values.first;
      final markets = firstBookie['markets'] as Map<String, dynamic>?;
      if (markets == null) return null;

      final predictions = _extractPredictions(markets);
      if (predictions.isEmpty) return null;

      predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
      final top4 = predictions.take(4).toList();
      final safety = top4.map((p) => p['confidence'] as double).reduce((a, b) => a + b) / top4.length;

      return {
        "home": home,
        "away": away,
        "predictions": top4,
        "safety": safety,
      };
    } catch (e) {
      return null;
    }
  }

  static String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static List<Map<String, dynamic>> _extractPredictions(Map<String, dynamic> markets) {
    List<Map<String, dynamic>> picks = [];

    void tryMarket(String marketId, String marketLabel, Map<String, String> outcomeLabels) {
      final market = markets[marketId];
      if (market == null) return;
      final outcomes = market['outcomes'] as Map<String, dynamic>?;
      if (outcomes == null) return;

      outcomes.forEach((outcomeId, outcome) {
        final players = outcome['players'] as Map<String, dynamic>?;
        final price = players?['0']?['price'];
        if (price != null && price is num && price > 1.0) {
          final label = outcomeLabels[outcomeId] ?? outcomeId;
          picks.add({
            "label": "$marketLabel: $label",
            "confidence": (1 / price) * 100,
            "marketId": marketId,
          });
        }
      });
    }

    tryMarket("101", "Match Result", {"101": "Home Win", "102": "Draw", "103": "Away Win"});
    tryMarket("104", "BTTS", {"104": "Yes", "105": "No"});
    tryMarket("106", "Goals", {"106": "Over", "107": "Under"});

    final Map<String, Map<String, dynamic>> bestPerMarket = {};
    for (var p in picks) {
      final mId = p['marketId'];
      if (!bestPerMarket.containsKey(mId) || p['confidence'] > bestPerMarket[mId]!['confidence']) {
        bestPerMarket[mId] = p;
      }
    }
    return bestPerMarket.values.toList();
  }

}

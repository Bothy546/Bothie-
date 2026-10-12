import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionService {
  static const String apiKey = "1a53deaf-aa03-404f-935a-a2a2c3e99211";
  static const String baseUrl = "https://api.oddspapi.io/v4";

  static Map<String, Map<String, dynamic>>? _catalog;

  static Future<void> _loadCatalog() async {
    if (_catalog != null) return;
    final url = Uri.parse("$baseUrl/markets?apiKey=$apiKey&sportId=10");
    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) { _catalog = {}; return; }
    final List list = jsonDecode(res.body);
    final map = <String, Map<String, dynamic>>{};
    for (var m in list) {
      final outcomes = <String, String>{};
      for (var o in (m['outcomes'] as List)) {
        outcomes[o['outcomeId'].toString()] = o['outcomeName'].toString();
      }
      map[m['marketId'].toString()] = {
        'name': (m['marketName'] ?? '').toString(),
        'type': (m['marketType'] ?? '').toString(),
        'handicap': m['handicap'],
        'period': (m['period'] ?? '').toString(),
        'outcomes': outcomes,
      };
    }
    _catalog = map;
  }

  static Future<List<Map<String, dynamic>>> getMatches() async {
    await _loadCatalog();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    final fixturesUrl = Uri.parse(
      "$baseUrl/fixtures?apiKey=$apiKey&sportId=10&from=${_fmt(today)}&to=${_fmt(tomorrow)}&hasOdds=true",
    );
    final fixturesRes = await http.get(fixturesUrl).timeout(const Duration(seconds: 10));
    if (fixturesRes.statusCode != 200) {
      throw Exception("Fixtures error: ${fixturesRes.statusCode}");
    }

    List fixtures = jsonDecode(fixturesRes.body);
    fixtures = fixtures.take(5).toList();

    List<Map<String, dynamic>> results = [];
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

      // Merge markets across all bookmakers (first valid price wins per outcome)
      Map<String, dynamic> mergedMarkets = {};
      for (var bk in bookmakerOdds.values) {
        final markets = bk['markets'] as Map<String, dynamic>?;
        if (markets == null) continue;
        markets.forEach((mid, mdata) {
          mergedMarkets.putIfAbsent(mid, () => mdata);
        });
      }

      final predictions = _extractPredictions(mergedMarkets);
      if (predictions.isEmpty) return null;

      predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
      final top4 = predictions.take(4).toList();
      final safety = top4.map((p) => p['confidence'] as double).reduce((a, b) => a + b) / top4.length;

      return {"home": home, "away": away, "predictions": top4, "safety": safety};
    } catch (e) {
      return null;
    }
  }

  static String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static List<Map<String, dynamic>> _extractPredictions(Map<String, dynamic> markets) {
    final catalog = _catalog ?? {};
    List<Map<String, dynamic>> picks = [];

    markets.forEach((marketId, marketData) {
      final info = catalog[marketId];
      if (info == null) return;
      final name = (info['name'] as String).toLowerCase();
      final period = (info['period'] as String).toLowerCase();
      final handicap = info['handicap'];
      final outcomesMeta = info['outcomes'] as Map<String, String>;

      String? group;
      if (name.contains("full time result") && period.contains("full")) {
        group = "Match Result";
      } else if (name.contains("both teams to score") && period.contains("full")) {
        group = "BTTS";
      } else if (name.contains("total") && period.contains("full") &&
          (handicap == 1.5 || handicap == 2.5)) {
        group = "Goals O/U $handicap";
      } else if ((name.contains("half") && name.contains("result")) ||
          (name.contains("full time result") && period.contains("half"))) {
        group = "First Half Result";
      }
      if (group == null) return;

      final outcomes = marketData['outcomes'] as Map<String, dynamic>?;
      if (outcomes == null) return;
      outcomes.forEach((outcomeId, outcome) {
        final players = outcome['players'] as Map<String, dynamic>?;
        final price = players?['0']?['price'];
        if (price != null && price is num && price > 1.0) {
          final outcomeName = outcomesMeta[outcomeId] ?? outcomeId;
          picks.add({
            "label": "$group: $outcomeName",
            "confidence": (1 / price) * 100,
            "group": group,
          });
        }
      });
    });

    final Map<String, Map<String, dynamic>> best = {};
    for (var p in picks) {
      final g = p['group'];
      if (!best.containsKey(g) || p['confidence'] > best[g]!['confidence']) {
        best[g] = p;
      }
    }
    return best.values.toList();
  }

}

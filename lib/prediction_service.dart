class PredictionService {
  // 🔧 MOCK MODE — no API calls, just test data
  static Future<List<Map<String, dynamic>>> getMatches() async {
    await Future.delayed(const Duration(seconds: 1)); // simulate loading

    final mockMatches = [
      {
        "home": "Arsenal",
        "away": "Chelsea",
        "predictions": [
          {"label": "BTTS: Yes", "confidence": 85.0},
          {"label": "Goals: Over 2.5", "confidence": 80.0},
          {"label": "Match Result: Home Win", "confidence": 72.0},
          {"label": "First Half Result: Draw", "confidence": 65.0},
        ],
      },
      {
        "home": "Man City",
        "away": "Liverpool",
        "predictions": [
          {"label": "Match Result: Home Win", "confidence": 78.0},
          {"label": "BTTS: Yes", "confidence": 74.0},
          {"label": "Goals: Over 2.5", "confidence": 70.0},
          {"label": "First Half Result: Home Lead", "confidence": 60.0},
        ],
      },
      {
        "home": "Real Madrid",
        "away": "Barcelona",
        "predictions": [
          {"label": "BTTS: Yes", "confidence": 90.0},
          {"label": "Goals: Over 2.5", "confidence": 88.0},
          {"label": "Match Result: Draw", "confidence": 55.0},
          {"label": "First Half Result: Draw", "confidence": 50.0},
        ],
      },
      {
        "home": "PSG",
        "away": "Marseille",
        "predictions": [
          {"label": "Match Result: Home Win", "confidence": 60.0},
          {"label": "Goals: Under 2.5", "confidence": 58.0},
          {"label": "BTTS: No", "confidence": 55.0},
          {"label": "First Half Result: Draw", "confidence": 48.0},
        ],
      },
    ];

    // Calculate safety score (average of its predictions)
    for (var match in mockMatches) {
      final preds = match['predictions'] as List<Map<String, dynamic>>;
      final avg = preds.map((p) => p['confidence'] as double).reduce((a, b) => a + b) / preds.length;
      match['safety'] = avg;
    }

    // Sort safest first
    mockMatches.sort((a, b) => (b['safety'] as double).compareTo(a['safety'] as double));

    return mockMatches;
  }

}

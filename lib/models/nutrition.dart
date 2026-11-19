class FoodEntry {
  FoodEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    required this.createdAt,
  });

  final String id;
  String date;
  String meal;
  String name;
  double calories;
  double protein;
  double carbs;
  double fat;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'meal': meal,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'created_at': createdAt.toIso8601String(),
      };

  factory FoodEntry.fromMap(Map<String, Object?> m) => FoodEntry(
        id: m['id'] as String,
        date: m['date'] as String,
        meal: m['meal'] as String,
        name: m['name'] as String,
        calories: (m['calories'] as num).toDouble(),
        protein: (m['protein'] as num? ?? 0).toDouble(),
        carbs: (m['carbs'] as num? ?? 0).toDouble(),
        fat: (m['fat'] as num? ?? 0).toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class StepEntry {
  StepEntry({
    required this.date,
    required this.steps,
    this.source = 'manual',
    required this.updatedAt,
  });

  final String date;
  int steps;
  String source;
  DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'date': date,
        'steps': steps,
        'source': source,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory StepEntry.fromMap(Map<String, Object?> m) => StepEntry(
        date: m['date'] as String,
        steps: m['steps'] as int,
        source: m['source'] as String,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

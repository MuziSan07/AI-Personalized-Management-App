class Milestone {
  Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    this.done = false,
    this.sortOrder = 0,
  });

  final String id;
  final String goalId;
  String title;
  bool done;
  int sortOrder;

  Map<String, Object?> toMap() => {
        'id': id,
        'goal_id': goalId,
        'title': title,
        'done': done ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory Milestone.fromMap(Map<String, Object?> m) => Milestone(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        title: m['title'] as String,
        done: (m['done'] as int? ?? 0) == 1,
        sortOrder: (m['sort_order'] as int?) ?? 0,
      );
}

class LearningGoal {
  LearningGoal({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.deadline,
    this.completed = false,
    required this.createdAt,
    this.milestones = const [],
  });

  final String id;
  String title;
  String? description;
  String category;
  String? deadline;
  bool completed;
  final DateTime createdAt;
  List<Milestone> milestones;

  double get progress {
    if (completed) return 1;
    if (milestones.isEmpty) return 0;
    return milestones.where((m) => m.done).length / milestones.length;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'deadline': deadline,
        'completed': completed ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory LearningGoal.fromMap(Map<String, Object?> m,
          {List<Milestone> milestones = const []}) =>
      LearningGoal(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        category: m['category'] as String,
        deadline: m['deadline'] as String?,
        completed: (m['completed'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        milestones: milestones,
      );
}

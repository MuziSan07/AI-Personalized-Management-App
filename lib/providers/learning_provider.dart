import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/learning.dart';
import '../repositories/learning_repository.dart';

class LearningProvider extends ChangeNotifier {
  LearningProvider(this._repo);

  final LearningRepository _repo;
  final _uuid = const Uuid();

  List<LearningGoal> goals = [];
  bool loading = true;

  Future<void> load() async {
    goals = await _repo.getAll();
    loading = false;
    notifyListeners();
  }

  List<LearningGoal> get active => goals.where((g) => !g.completed).toList();
  List<LearningGoal> get completed => goals.where((g) => g.completed).toList();

  LearningGoal newGoal() => LearningGoal(
        id: _uuid.v4(),
        title: '',
        category: 'Programming',
        createdAt: DateTime.now(),
        milestones: [],
      );

  Milestone newMilestone(String goalId, String title) =>
      Milestone(id: _uuid.v4(), goalId: goalId, title: title);

  Future<void> save(LearningGoal g) async {
    await _repo.upsert(g);
    await load();
  }

  Future<void> toggleMilestone(LearningGoal g, Milestone m) async {
    m.done = !m.done;
    if (g.milestones.isNotEmpty && g.milestones.every((x) => x.done)) {
      g.completed = true;
    } else if (g.completed && !m.done) {
      g.completed = false;
    }
    await _repo.upsert(g);
    await load();
  }

  Future<void> setCompleted(LearningGoal g, bool value) async {
    g.completed = value;
    if (value) {
      for (final m in g.milestones) {
        m.done = true;
      }
    }
    await _repo.upsert(g);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }

  String summaryForAi() {
    if (goals.isEmpty) return 'Learning goals: none yet.';
    final b = StringBuffer('Learning goals:\n');
    for (final g in goals) {
      b.writeln('- ${g.title} [${g.category}] ${(g.progress * 100).round()}%'
          '${g.deadline == null ? '' : ', due ${g.deadline}'}'
          '${g.completed ? ' (completed)' : ''}'
          '${g.milestones.isEmpty ? '' : ': ${g.milestones.map((m) => '${m.done ? '[x]' : '[ ]'} ${m.title}').join(', ')}'}');
    }
    return b.toString();
  }
}

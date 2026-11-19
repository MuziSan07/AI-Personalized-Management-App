import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/date_utils.dart';
import '../models/activity.dart';
import '../models/chat.dart';
import '../repositories/chat_repository.dart';
import '../services/ai_actions.dart';
import '../services/ai_prompts.dart';
import '../services/groq_service.dart';
import 'activity_provider.dart';
import 'finance_provider.dart';
import 'health_provider.dart';
import 'learning_provider.dart';
import 'settings_provider.dart';

/// Chat with the Groq-powered coach and apply the actions it proposes.
class AssistantProvider extends ChangeNotifier {
  AssistantProvider({
    required ChatRepository chatRepo,
    required this.settings,
    required this.activities,
    required this.finance,
    required this.health,
    required this.learning,
  }) : _chatRepo = chatRepo;

  final ChatRepository _chatRepo;
  final SettingsProvider settings;
  final ActivityProvider activities;
  final FinanceProvider finance;
  final HealthProvider health;
  final LearningProvider learning;
  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  bool sending = false;
  String? error;
  String? insight;
  bool insightLoading = false;

  GroqService get groq => GroqService(modelOverride: settings.groqModel);
  bool get configured => GroqService.isConfigured;

  AiActionApplier get _applier => AiActionApplier(
        activities: activities,
        finance: finance,
        health: health,
        learning: learning,
      );

  Future<void> load() async {
    messages = await _chatRepo.getAll();
    final p = await SharedPreferences.getInstance();
    if (p.getString('insight_date') == D.todayKey()) {
      insight = p.getString('insight_text');
    }
    notifyListeners();
  }

  String buildContext() => [
        activities.summaryForAi(),
        finance.summaryForAi(settings.currency),
        health.summaryForAi(
            calorieTarget: settings.calorieTarget, stepGoal: settings.stepGoal),
        learning.summaryForAi(),
      ].join('\n');

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || sending) return;
    error = null;
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: t,
      createdAt: DateTime.now(),
    );
    messages.add(userMsg);
    await _chatRepo.upsert(userMsg);
    sending = true;
    notifyListeners();

    try {
      final recent = messages.where((m) => m.role != ChatRole.system).toList();
      final start = recent.length > 12 ? recent.length - 12 : 0;
      final history = recent
          .sublist(start)
          .map((m) => {'role': m.role.name, 'content': m.content})
          .toList();
      final system = AiPrompts.system(
        today: '${D.long(DateTime.now())} (${D.todayKey()})',
        profile: settings.profileSummary,
        context: buildContext(),
      );
      final json = await groq.chatJson(
        [
          {'role': 'system', 'content': system},
          ...history,
        ],
        temperature: 0.5,
      );
      final reply = (json['reply'] ?? json['message'] ?? '').toString().trim();
      final actions = <AiAction>[];
      for (final a in (json['actions'] as List?) ?? []) {
        if (a is Map && a['type'] != null) {
          actions.add(AiAction(
            type: a['type'].toString(),
            data: Map<String, dynamic>.from((a['data'] as Map?) ?? a),
          ));
        }
      }
      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        content: reply.isEmpty
            ? (actions.isEmpty ? 'Done.' : 'Here is what I prepared for you:')
            : reply,
        actions: actions,
        createdAt: DateTime.now(),
      );
      messages.add(aiMsg);
      await _chatRepo.upsert(aiMsg);
    } catch (e) {
      error = e.toString();
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<String?> applyAction(ChatMessage m, AiAction a) async {
    try {
      await _applier.apply(a);
      a.applied = true;
      await _chatRepo.upsert(m);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<String>> applyAll(ChatMessage m) async {
    final errors = <String>[];
    for (final a in m.actions.where((a) => !a.applied)) {
      final err = await applyAction(m, a);
      if (err != null) errors.add(err);
    }
    return errors;
  }

  Future<void> clear() async {
    await _chatRepo.clear();
    messages = [];
    notifyListeners();
  }

  // ---- Helpers used by other screens ----

  Future<Map<String, dynamic>> estimateMacros(String description) async {
    return groq.chatJson([
      {'role': 'system', 'content': AiPrompts.macroEstimator},
      {'role': 'user', 'content': description},
    ]);
  }

  Future<List<Activity>> generateWorkoutPlan(String request) async {
    final json = await groq.chatJson([
      {
        'role': 'system',
        'content': AiPrompts.workoutPlanner(settings.profileSummary)
      },
      {'role': 'user', 'content': request},
    ], maxTokens: 2500);
    final out = <Activity>[];
    for (final a in (json['activities'] as List?) ?? []) {
      if (a is! Map) continue;
      final act = activities.newActivity()
        ..title = (a['title'] ?? 'Workout').toString()
        ..category = (a['category'] ?? 'Gym').toString()
        ..notes = a['notes']?.toString()
        ..recurrence = Recurrence.weekly
        ..weekdays = ((a['weekdays'] as List?) ?? [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((w) => w >= 1 && w <= 7)
            .toList()
        ..icon = (a['category'] ?? '').toString() == 'Calisthenics'
            ? 'calisthenics'
            : 'fitness';
      final rt = (a['reminder_time'] ?? '').toString();
      if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(rt)) {
        act.reminderTime = rt.padLeft(5, '0');
        act.reminderEnabled = true;
      }
      if (act.weekdays.isEmpty) act.weekdays = [1];
      act.items = [
        for (final it in (a['items'] as List?) ?? [])
          if (it is Map)
            activities.newItem(act.id, (it['title'] ?? 'Exercise').toString(),
                detail: it['detail']?.toString()),
      ];
      out.add(act);
    }
    return out;
  }

  Future<void> refreshInsight({bool force = false}) async {
    if (!configured) return;
    if (!force && insight != null) return;
    insightLoading = true;
    notifyListeners();
    try {
      final text = await groq.chat([
        {
          'role': 'user',
          'content': AiPrompts.insight(
              settings.profileSummary, buildContext(), D.long(DateTime.now()))
        }
      ], temperature: 0.7, maxTokens: 220);
      insight = text;
      final p = await SharedPreferences.getInstance();
      await p.setString('insight_date', D.todayKey());
      await p.setString('insight_text', text);
    } catch (e) {
      error = e.toString();
    } finally {
      insightLoading = false;
      notifyListeners();
    }
  }

  Future<String> weeklyReview() => groq.chat([
        {
          'role': 'user',
          'content': AiPrompts.weeklyReview(
              settings.profileSummary, buildContext(), D.long(DateTime.now()))
        }
      ], temperature: 0.6, maxTokens: 600);
}

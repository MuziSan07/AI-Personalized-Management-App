import '../core/date_utils.dart';
import '../models/activity.dart';
import '../models/chat.dart';
import '../models/finance.dart';
import '../providers/activity_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/health_provider.dart';
import '../providers/learning_provider.dart';

/// Applies an [AiAction] proposed by the assistant to the local database.
class AiActionApplier {
  AiActionApplier({
    required this.activities,
    required this.finance,
    required this.health,
    required this.learning,
  });

  final ActivityProvider activities;
  final FinanceProvider finance;
  final HealthProvider health;
  final LearningProvider learning;

  double _num(dynamic v, [double def = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? def;
    return def;
  }

  String _str(dynamic v, [String def = '']) =>
      v == null ? def : v.toString().trim();

  String _date(dynamic v) {
    final s = _str(v);
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
    return D.todayKey();
  }

  String _pick(String value, List<String> allowed, String def) {
    for (final a in allowed) {
      if (a.toLowerCase() == value.toLowerCase()) return a;
    }
    return def;
  }

  /// Human-readable label used on the action card before it is applied.
  static String describe(AiAction a) {
    final d = a.data;
    switch (a.type) {
      case 'add_expense':
        return 'Expense ${d['amount']} - ${d['category']}${d['note'] == null ? '' : ' - ${d['note']}'}';
      case 'add_income':
        return 'Income ${d['amount']} - ${d['category']}${d['note'] == null ? '' : ' - ${d['note']}'}';
      case 'add_food':
        return 'Food: ${d['name']} - ${d['calories']} kcal (P${d['protein']} C${d['carbs']} F${d['fat']})';
      case 'log_steps':
        return '${d['mode'] == 'add' ? 'Add' : 'Set'} ${d['steps']} steps';
      case 'add_activity':
        final items = (d['items'] as List?)?.length ?? 0;
        return 'Activity: ${d['title']} (${d['recurrence']})${items > 0 ? ' - $items items' : ''}';
      case 'complete_activity':
        return 'Mark "${d['title']}" complete';
      case 'add_learning_goal':
        return 'Learning goal: ${d['title']}';
      case 'add_loan':
        return '${d['direction'] == 'lent' ? 'Lent to' : 'Borrowed from'} ${d['person']}: ${d['amount']}';
      case 'add_savings_goal':
        return 'Savings goal: ${d['title']} (target ${d['target_amount']})';
      case 'add_to_savings':
        return 'Add ${d['amount']} to "${d['title']}"';
      default:
        return a.type;
    }
  }

  Future<void> apply(AiAction a) async {
    final d = a.data;
    switch (a.type) {
      case 'add_expense':
      case 'add_income':
        final isIncome = a.type == 'add_income';
        final t = finance
            .newTransaction(isIncome ? TxType.income : TxType.expense)
          ..amount = _num(d['amount'])
          ..category = _pick(
              _str(d['category']), isIncome ? kIncome : kExpense, 'Other')
          ..note = _str(d['note']).isEmpty ? null : _str(d['note'])
          ..date = _date(d['date']);
        if (t.amount <= 0) throw Exception('Amount must be positive');
        await finance.saveTransaction(t);
      case 'add_food':
        final f = health.newFood(meal: _pick(_str(d['meal']), kMealsList, 'Snack'))
          ..name = _str(d['name'], 'Food')
          ..calories = _num(d['calories'])
          ..protein = _num(d['protein'])
          ..carbs = _num(d['carbs'])
          ..fat = _num(d['fat'])
          ..date = _date(d['date']);
        await health.saveFood(f);
      case 'log_steps':
        final steps = _num(d['steps']).round();
        final target = _date(d['date']);
        final prev = health.date;
        if (D.key(prev) != target) await health.selectDate(D.parse(target));
        if (_str(d['mode']) == 'add') {
          await health.addSteps(steps);
        } else {
          await health.setSteps(steps);
        }
        if (D.key(prev) != target) await health.selectDate(prev);
      case 'add_activity':
        final act = activities.newActivity()
          ..title = _str(d['title'], 'New activity')
          ..category = _pick(_str(d['category']), kActCats, 'Personal')
          ..notes = _str(d['notes']).isEmpty ? null : _str(d['notes'])
          ..recurrence = Recurrence.values.firstWhere(
              (r) => r.name == _str(d['recurrence']).toLowerCase(),
              orElse: () => Recurrence.daily)
          ..weekdays = ((d['weekdays'] as List?) ?? [])
              .map((e) => _num(e).round())
              .where((w) => w >= 1 && w <= 7)
              .toList()
          ..dayOfMonth = d['day_of_month'] == null
              ? null
              : _num(d['day_of_month']).round()
          ..startDate = d['date'] == null ? null : D.parse(_date(d['date']))
          ..icon = _iconFor(_str(d['category']));
        final rt = _str(d['reminder_time']);
        if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(rt)) {
          act.reminderTime = rt.padLeft(5, '0');
          act.reminderEnabled = true;
        }
        if (act.recurrence == Recurrence.weekly && act.weekdays.isEmpty) {
          act.weekdays = [DateTime.now().weekday];
        }
        if (act.recurrence == Recurrence.once && act.startDate == null) {
          act.startDate = D.today();
        }
        act.items = [
          for (final it in (d['items'] as List?) ?? [])
            if (it is Map)
              activities.newItem(act.id, _str(it['title'], 'Item'),
                  detail:
                      _str(it['detail']).isEmpty ? null : _str(it['detail']))
            else
              activities.newItem(act.id, it.toString()),
        ];
        await activities.save(act);
      case 'complete_activity':
        final title = _str(d['title']).toLowerCase();
        final match = activities.all
                .where((x) => x.title.toLowerCase() == title)
                .firstOrNull ??
            activities.all
                .where((x) => x.title.toLowerCase().contains(title))
                .firstOrNull;
        if (match == null) {
          throw Exception('No activity named "${d['title']}"');
        }
        if (!activities.isActivityDone(match)) {
          await activities.toggleActivity(match);
        }
      case 'add_learning_goal':
        final g = learning.newGoal()
          ..title = _str(d['title'], 'New goal')
          ..category = _pick(_str(d['category']), kLearnCats, 'Other')
          ..description =
              _str(d['description']).isEmpty ? null : _str(d['description'])
          ..deadline = d['deadline'] == null ? null : _date(d['deadline']);
        g.milestones = [
          for (final m in (d['milestones'] as List?) ?? [])
            learning.newMilestone(
                g.id, m is Map ? _str(m['title']) : m.toString()),
        ];
        await learning.save(g);
      case 'add_loan':
        final l = finance.newLoan(_str(d['direction']) == 'borrowed'
            ? LoanDirection.borrowed
            : LoanDirection.lent)
          ..person = _str(d['person'], 'Someone')
          ..amount = _num(d['amount'])
          ..note = _str(d['note']).isEmpty ? null : _str(d['note'])
          ..dueDate = d['due_date'] == null ? null : _date(d['due_date']);
        await finance.saveLoan(l);
      case 'add_savings_goal':
        final g = finance.newGoal()
          ..title = _str(d['title'], 'Savings')
          ..targetAmount = _num(d['target_amount'])
          ..savedAmount = _num(d['saved_amount'])
          ..deadline = d['deadline'] == null ? null : _date(d['deadline']);
        await finance.saveGoal(g);
      case 'add_to_savings':
        final title = _str(d['title']).toLowerCase();
        final g = finance.goals
                .where((x) => x.title.toLowerCase() == title)
                .firstOrNull ??
            finance.goals
                .where((x) => x.title.toLowerCase().contains(title))
                .firstOrNull;
        if (g == null) {
          throw Exception('No savings goal named "${d['title']}"');
        }
        await finance.addToGoal(g, _num(d['amount']));
      default:
        throw Exception('Unknown action "${a.type}"');
    }
  }

  static String _iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'gym':
        return 'fitness';
      case 'calisthenics':
        return 'calisthenics';
      case 'professional work':
        return 'work';
      case 'freelance':
        return 'laptop';
      case 'learning':
        return 'book';
      case 'health':
        return 'health';
      case 'household':
        return 'home';
      default:
        return 'check';
    }
  }

  static const kExpense = [
    'Food', 'Transport', 'Gym', 'Rent', 'Bills', 'Shopping', 'Health',
    'Entertainment', 'Education', 'Loan Repayment', 'Other'
  ];
  static const kIncome = [
    'Professional Work', 'Freelance', 'Business', 'Gift', 'Loan Received',
    'Investment', 'Other'
  ];
  static const kActCats = [
    'Gym', 'Calisthenics', 'Professional Work', 'Freelance', 'Learning',
    'Health', 'Personal', 'Household', 'Other'
  ];
  static const kLearnCats = [
    'Programming', 'Language', 'Career', 'Fitness Knowledge', 'Finance',
    'Creative', 'Other'
  ];
  static const kMealsList = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
}

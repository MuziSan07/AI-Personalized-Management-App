enum TxType { income, expense }

class Transaction {
  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.createdAt,
  });

  final String id;
  TxType type;
  double amount;
  String category;
  String? note;
  /// yyyy-MM-dd
  String date;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date,
        'created_at': createdAt.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as String,
        type: m['type'] == 'income' ? TxType.income : TxType.expense,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String,
        note: m['note'] as String?,
        date: m['date'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// `lent` = I gave money to someone (they owe me).
/// `borrowed` = someone gave me money (I owe them).
enum LoanDirection { lent, borrowed }

class Loan {
  Loan({
    required this.id,
    required this.person,
    required this.amount,
    required this.direction,
    this.note,
    required this.date,
    this.dueDate,
    this.settled = false,
    this.settledAt,
  });

  final String id;
  String person;
  double amount;
  LoanDirection direction;
  String? note;
  String date;
  String? dueDate;
  bool settled;
  DateTime? settledAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'person': person,
        'amount': amount,
        'direction': direction.name,
        'note': note,
        'date': date,
        'due_date': dueDate,
        'settled': settled ? 1 : 0,
        'settled_at': settledAt?.toIso8601String(),
      };

  factory Loan.fromMap(Map<String, Object?> m) => Loan(
        id: m['id'] as String,
        person: m['person'] as String,
        amount: (m['amount'] as num).toDouble(),
        direction:
            m['direction'] == 'lent' ? LoanDirection.lent : LoanDirection.borrowed,
        note: m['note'] as String?,
        date: m['date'] as String,
        dueDate: m['due_date'] as String?,
        settled: (m['settled'] as int? ?? 0) == 1,
        settledAt: m['settled_at'] == null
            ? null
            : DateTime.parse(m['settled_at'] as String),
      );
}

class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
    required this.createdAt,
  });

  final String id;
  String title;
  double targetAmount;
  double savedAmount;
  String? deadline;
  final DateTime createdAt;

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'deadline': deadline,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['id'] as String,
        title: m['title'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        savedAmount: (m['saved_amount'] as num).toDouble(),
        deadline: m['deadline'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

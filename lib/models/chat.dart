import 'dart:convert';

enum ChatRole { user, assistant, system }

/// An action the assistant proposed; the user applies it with one tap.
class AiAction {
  AiAction({required this.type, required this.data, this.applied = false});

  final String type;
  final Map<String, dynamic> data;
  bool applied;

  Map<String, dynamic> toJson() =>
      {'type': type, 'data': data, 'applied': applied};

  factory AiAction.fromJson(Map<String, dynamic> j) => AiAction(
        type: j['type'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map? ?? {}),
        applied: j['applied'] == true,
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.actions = const [],
    required this.createdAt,
  });

  final String id;
  final ChatRole role;
  final String content;
  List<AiAction> actions;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'actions_json': actions.isEmpty
            ? null
            : jsonEncode(actions.map((a) => a.toJson()).toList()),
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, Object?> m) {
    final raw = m['actions_json'] as String?;
    final actions = raw == null
        ? <AiAction>[]
        : (jsonDecode(raw) as List)
            .map((e) => AiAction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
    return ChatMessage(
      id: m['id'] as String,
      role: ChatRole.values.firstWhere((r) => r.name == m['role']),
      content: m['content'] as String,
      actions: actions,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

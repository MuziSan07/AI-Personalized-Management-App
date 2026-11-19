import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat.dart';
import '../../providers/assistant_provider.dart';
import '../../services/ai_actions.dart';
import '../../widgets/common.dart';

/// Shows an AI-generated weekly review in a dialog.
Future<void> showWeeklyReview(BuildContext context) async {
  final ai = context.read<AssistantProvider>();
  if (!ai.configured) {
    snack(context, 'Add GROQ_API_KEY to .env to use the AI coach.',
        error: true);
    return;
  }
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));
  String text;
  try {
    text = await ai.weeklyReview();
  } catch (e) {
    text = e.toString();
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Weekly review'),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _suggestions = [
    'Add expense 450 for lunch today',
    'Create a shoulders workout for Monday and Thursday at 6pm with reminders',
    'I ate 2 eggs, a paratha and chai for breakfast',
    'Log 8,500 steps for today',
    'I lent Ali 5000, due next Friday',
    'Set a learning goal: finish the Flutter course by end of month',
    'How am I doing on my budget this month?',
    'Plan my day based on what I have scheduled',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = (text ?? _input.text).trim();
    if (t.isEmpty) return;
    _input.clear();
    context.read<AssistantProvider>().send(t);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AssistantProvider>();
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    if (ai.sending) _scrollToEnd();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coach'),
                Text(ai.groq.model,
                    style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: ai.messages.isEmpty
                ? null
                : () async {
                    if (await confirm(context, 'Clear conversation?',
                        'Your logged data stays; only the chat is removed.',
                        okLabel: 'Clear')) {
                      ai.clear();
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!ai.configured)
            MaterialBanner(
              backgroundColor: scheme.errorContainer,
              content: const Text(
                  'Groq API key missing. Put GROQ_API_KEY=... in the .env file at the project root and rebuild the app.'),
              leading: Icon(Icons.key_off, color: scheme.onErrorContainer),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: ai.messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 20),
                      Icon(Icons.auto_awesome,
                          size: 48, color: scheme.primary.withValues(alpha: .6)),
                      const SizedBox(height: 12),
                      Text('Your personal coach',
                          textAlign: TextAlign.center,
                          style: t.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        'I know your plan, budget, meals, steps and goals. Ask me anything, or just tell me what happened and I will log it for you.',
                        textAlign: TextAlign.center,
                        style: t.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ..._suggestions.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12)),
                              onPressed: () => _send(s),
                              child: Text(s),
                            ),
                          )),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: ai.messages.length + (ai.sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == ai.messages.length) {
                        return const _Typing();
                      }
                      return _Bubble(message: ai.messages[i]);
                    },
                  ),
          ),
          if (ai.error != null)
            Container(
              width: double.infinity,
              color: scheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(ai.error!,
                  style: t.bodySmall?.copyWith(color: scheme.onErrorContainer)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          hintText: 'Tell me what happened or ask anything'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: ai.sending ? null : _send,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isUser = message.role == ChatRole.user;
    final ai = context.read<AssistantProvider>();
    final pending = message.actions.where((a) => !a.applied).length;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: SelectableText(
                message.content,
                style: t.bodyMedium?.copyWith(
                    color: isUser ? scheme.onPrimary : scheme.onSurface,
                    height: 1.35),
              ),
            ),
            if (message.actions.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt, size: 16, color: scheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                                pending == 0
                                    ? 'All ${message.actions.length} applied'
                                    : '$pending action${pending == 1 ? '' : 's'} to apply',
                                style: t.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          if (pending > 1)
                            TextButton(
                              onPressed: () async {
                                final errs = await ai.applyAll(message);
                                if (context.mounted) {
                                  snack(
                                      context,
                                      errs.isEmpty
                                          ? 'Applied all actions.'
                                          : errs.join('\n'),
                                      error: errs.isNotEmpty);
                                }
                              },
                              child: const Text('Apply all'),
                            ),
                        ],
                      ),
                      ...message.actions.map((a) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  a.applied
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: a.applied
                                      ? Colors.green
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(AiActionApplier.describe(a),
                                        style: t.bodySmall)),
                                if (!a.applied)
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12)),
                                    onPressed: () async {
                                      final err =
                                          await ai.applyAction(message, a);
                                      if (context.mounted) {
                                        snack(context, err ?? 'Applied.',
                                            error: err != null);
                                      }
                                    },
                                    child: const Text('Apply'),
                                  ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 36,
          height: 14,
          child: LinearProgressIndicator(minHeight: 3),
        ),
      ),
    );
  }
}

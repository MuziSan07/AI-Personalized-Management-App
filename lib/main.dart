import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/activity_provider.dart';
import 'providers/assistant_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/health_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/activity_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/health_repository.dart';
import 'repositories/learning_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Missing .env is fine: the app works, AI features just show a hint.
  await dotenv.load(fileName: '.env', isOptional: true);
  await NotificationService.instance.init();
  final settings = SettingsProvider();
  await settings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
            create: (_) => ActivityProvider(ActivityRepository())..load()),
        ChangeNotifierProvider(
            create: (_) => FinanceProvider(FinanceRepository())..load()),
        ChangeNotifierProvider(
            create: (_) => HealthProvider(HealthRepository())..load()),
        ChangeNotifierProvider(
            create: (_) => LearningProvider(LearningRepository())..load()),
        ChangeNotifierProvider(
          create: (ctx) => AssistantProvider(
            chatRepo: ChatRepository(),
            settings: ctx.read<SettingsProvider>(),
            activities: ctx.read<ActivityProvider>(),
            finance: ctx.read<FinanceProvider>(),
            health: ctx.read<HealthProvider>(),
            learning: ctx.read<LearningProvider>(),
          )..load(),
        ),
      ],
      child: const App(),
    ),
  );
}

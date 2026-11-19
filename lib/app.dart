import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/activity_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/activities/activities_screen.dart';
import 'screens/assistant/assistant_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/finance/finance_screen.dart';
import 'screens/learning/learning_screen.dart';
import 'screens/nutrition/health_screen.dart';
import 'services/notification_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Life Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

/// Bottom-navigation shell. Tabs keep their state via IndexedStack.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
  }

  Future<void> _firstRun() async {
    final settings = context.read<SettingsProvider>();
    if (settings.onboarded) return;
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleDailySummary(
        enabled: settings.dailySummaryEnabled, time: settings.dailySummaryTime);
    settings.onboarded = true;
    await settings.save();
    if (mounted) await context.read<ActivityProvider>().rescheduleAll();
  }

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onNavigate: goTo),
      const ActivitiesScreen(),
      const FinanceScreen(),
      const HealthScreen(),
      const LearningScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ai-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AssistantScreen()),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Coach'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Plan'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Money'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'Health'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Learn'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF5B5FEF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.light
          ? const Color(0xFFF6F7FB)
          : const Color(0xFF0F1115),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

/// Palette for user-selectable colours (activities, categories).
const kPalette = <Color>[
  Color(0xFF5B5FEF),
  Color(0xFF00B894),
  Color(0xFFFF7675),
  Color(0xFFFDCB6E),
  Color(0xFF0984E3),
  Color(0xFFE17055),
  Color(0xFF6C5CE7),
  Color(0xFF00CEC9),
  Color(0xFFD63031),
  Color(0xFF2D3436),
];

const kActivityIcons = <String, IconData>{
  'fitness': Icons.fitness_center,
  'calisthenics': Icons.sports_gymnastics,
  'run': Icons.directions_run,
  'work': Icons.work_outline,
  'laptop': Icons.laptop_mac,
  'book': Icons.menu_book,
  'school': Icons.school_outlined,
  'food': Icons.restaurant,
  'water': Icons.water_drop_outlined,
  'sleep': Icons.bedtime_outlined,
  'meditate': Icons.self_improvement,
  'money': Icons.savings_outlined,
  'home': Icons.home_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'health': Icons.favorite_border,
  'star': Icons.star_border,
  'check': Icons.check_circle_outline,
  'bolt': Icons.bolt,
};

const kActivityCategories = <String>[
  'Gym',
  'Calisthenics',
  'Professional Work',
  'Freelance',
  'Learning',
  'Health',
  'Personal',
  'Household',
  'Other',
];

const kExpenseCategories = <String>[
  'Food',
  'Transport',
  'Gym',
  'Rent',
  'Bills',
  'Shopping',
  'Health',
  'Entertainment',
  'Education',
  'Loan Repayment',
  'Other',
];

const kIncomeCategories = <String>[
  'Professional Work',
  'Freelance',
  'Business',
  'Gift',
  'Loan Received',
  'Investment',
  'Other',
];

const kLearningCategories = <String>[
  'Programming',
  'Language',
  'Career',
  'Fitness Knowledge',
  'Finance',
  'Creative',
  'Other',
];

const kMeals = <String>['Breakfast', 'Lunch', 'Dinner', 'Snack'];

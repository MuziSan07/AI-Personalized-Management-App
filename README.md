# AI Life Manager

A personal, AI-powered life management app built with **Flutter**. Everything is stored **locally on your phone** (SQLite); the only network call is to **Groq Cloud** for the AI coach.

## What it does

| Area | Features |
| --- | --- |
| **Plan** (activities & habits) | Daily / weekly / monthly / one-time activities with categories (Gym, Calisthenics, Professional Work, Freelance, Learning, ...). Each activity can hold a checklist, e.g. a *Shoulders day* with every exercise (sets x reps) as its own checkbox. Per-day completion history, progress ring, date strip to review any day. |
| **Reminders** | Local notifications per activity (daily, specific weekdays, or day of month) plus a configurable daily summary notification. Survive reboots on Android. |
| **Money** | Income (professional work, freelance, business ...), expenses by category, loans you lent or borrowed (settling one records the payment automatically), savings goals with progress. Monthly overview with category pie chart, 7-day spending bar chart, balance, net. |
| **Health** | Calorie & macro tracker (protein / carbs / fat) per meal with daily targets. **AI macro estimation**: type "2 eggs and a paratha" and let the coach fill in the numbers. Steps with a 10K (configurable) goal, manual logging, quick add, optional live counting from the phone's step sensor, 14-day chart. |
| **Learn** | Learning goals with category, deadline and milestones as checkboxes; progress auto-calculated. |
| **AI Coach** (Groq) | Chat that knows your live data (today's plan, budget, meals, steps, goals). Tell it what happened in plain language and it proposes **actions** you apply with one tap: add expense/income, log food, log steps, create activities with exercise lists and reminders, complete an activity, add loans, savings goals and learning goals. Also: daily insight on the dashboard, AI-generated training plans, and a weekly review. |
| **Dashboard** | Greeting, coach insight, today's plan with quick checkboxes, steps / calories / spending / learning tiles, quick-log buttons, monthly income vs expenses. |

## Setup

### 1. Requirements

- Flutter 3.41+ (Dart 3.11+) - `flutter doctor` should show Android toolchain OK.
- Android device/emulator (iOS also configured; needs a Mac to build).

### 2. Groq API key

Copy `.env.example` to `.env` and paste your key from <https://console.groq.com/keys>:

```env
GROQ_API_KEY=gsk_your_key_here
GROQ_MODEL=llama-3.3-70b-versatile   # optional
```

`.env` is bundled as an asset and is git-ignored. Without a key the app still works fully; only AI features show a hint. You can also pick a model in **Settings > AI**.

### 3. Run

```powershell
flutter pub get
flutter run
```

Build a release APK:

```powershell
flutter build apk --release
```

## Project structure

```
lib/
  main.dart                 app bootstrap, providers
  app.dart                  theme + bottom-navigation shell
  core/                     SQLite schema, theme & constants, date/format helpers
  models/                   Activity, Transaction, Loan, SavingsGoal, FoodEntry, StepEntry, LearningGoal, ChatMessage
  repositories/             sqflite data access per domain
  providers/                ChangeNotifier state (activities, finance, health, learning, settings, assistant)
  services/
    groq_service.dart       Groq Cloud chat-completions client (JSON mode)
    ai_prompts.dart         system prompts + action schema
    ai_actions.dart         applies AI-proposed actions to the local DB
    notification_service.dart  flutter_local_notifications scheduling
  screens/                  dashboard, activities, finance, nutrition (health), learning, assistant, settings
  widgets/common.dart       shared UI pieces
```

## Notes

- **Notifications on Android 13+** ask for permission on first launch. Exact-alarm permission is requested as well; reminders use inexact "allow while idle" scheduling, which is battery friendly and reliable.
- **Step sensor** needs the *Physical activity* permission. Counting runs while the app is open; manual logging always works.
- **Privacy**: only your chat text plus a compact text summary of your data is sent to Groq when you use AI features. Nothing else leaves the device.

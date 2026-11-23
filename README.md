# Daily Expense Tracker (Zero gentic)

The version of the app for the Play Store and App Store. It has **no SMS access**: expenses and income are added by hand. The SMS auto-tracking version lives in a separate repository (`Zerogentic/expense-tracker`).

- Android package / iOS bundle ID: `com.zerogentic.expensetracker` (can't change after the first store upload)
- All data stays on the phone in a local database. No account, no server, no ads.

## Features

- **Overview:** total spent with budget bar, received and net, per-day / biggest / top-place insights, category donut, 6-month cash flow, recent activity.
- **Add in seconds:** amount, payee, date, note; the category is suggested from the payee and learns from your choices.
- **Categories:** built-in set plus your own (name, icon, colour). Changing a category offers to update other transactions from the same payee.
- **Not an expense:** switch any transaction out of totals (transfers between your accounts, investments).
- **Rename payees** across all their transactions.
- **Budgets:** monthly total and per category, amber at 80%, red at 100%.
- **Bills:** monthly bills with due dates; marking one paid records the expense.
- **Activity:** search, filters, day totals in red (spent) and green (received).

## Builds

Every push to `main` runs **Build** (Actions tab):

- **Android test APK:** published on the **Releases** page as `daily-expense-tracker-N.apk`. Install it on an Android phone directly; Play Protect doesn't block it because the app asks for no sensitive permissions.
- **iOS build check:** compiles the app for iPhone without signing, to catch iOS-only problems early.

## Before the store release

- Google Play developer account, a private upload key (stored as GitHub secrets), and an `.aab` build.
- Apple Developer account, signing certificates, and a TestFlight upload.
- App icon, store screenshots, privacy policy URL, and the Play Data safety / App Store privacy forms.

## Project layout

```
lib/
  main.dart                 app shell and bottom navigation
  state.dart                app state and queries
  models.dart               transactions, bills, categories
  services/db.dart          local SQLite database
  services/categorizer.dart keyword + learned categories
  screens/                  overview, activity, budgets, bills, add, settings
  widgets/                  charts, transaction tiles and sheets
test/                       formatting, category and bill tests
```

The Android and iOS project folders are generated during the build by `flutter create`.

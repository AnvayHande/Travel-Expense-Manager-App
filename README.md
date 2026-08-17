# Trip Expense Manager

A production-ready Flutter application for managing and splitting trip expenses with friends and family, powered by Firebase.

## Architecture

Clean Architecture with Riverpod state management and Firebase backend.

```
lib/
├── core/
│   ├── constants/           # App-wide constants
│   ├── exceptions/          # Custom exception classes & Firebase error handler
│   ├── models/              # Domain models with JSON serialization
│   ├── repositories/        # Abstract interfaces + Firebase implementations
│   ├── services/            # Firebase service wrappers (Auth, Firestore, Storage)
│   ├── theme/               # Material 3 light/dark theme
│   ├── utils/               # Formatters, validators, logger
│   └── widgets/             # Reusable UI components
├── features/                # Feature modules with placeholder screens
│   ├── authentication/      # Login / Signup
│   ├── trip/                # Home, Create Trip, Trip Details, Participants
│   ├── expense/             # Expenses list, Add Expense
│   ├── settlement/          # Settlement screen
│   ├── export/              # Export screen
│   └── settings/            # Settings screen
├── presentation/
│   ├── providers/           # Riverpod state providers (Auth, Trip, Expense, Theme, Firebase)
│   └── routes/              # GoRouter route definitions
├── app.dart                 # MaterialApp.router with theming
├── firebase_options.dart    # Firebase configuration (run flutterfire configure)
└── main.dart                # Entry point with Firebase initialization gateway
```

## Tech Stack

| Technology | Purpose |
|-----------|---------|
| Flutter 3.44+ | UI Framework |
| Material 3 | Design System (light + dark mode) |
| Riverpod 2.x | State Management |
| GoRouter 14.x | Declarative Routing |
| Firebase Core | Backend initialization |
| Firebase Auth | Authentication |
| Cloud Firestore | NoSQL Database |
| Firebase Storage | File Storage |

## Firebase Setup

This project requires a Firebase project to function. The app includes a graceful error screen if Firebase is not configured.

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for this project
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID

# This will generate:
#   - lib/firebase_options.dart
#   - android/app/google-services.json
#   - ios/Runner/GoogleService-Info.plist
```

### Manual Firebase Configuration

1. Create a project in [Firebase Console](https://console.firebase.google.com)
2. Enable Authentication (Email/Password)
3. Create a Cloud Firestore database
4. Enable Firebase Storage
5. Register Android & iOS apps in Firebase Console
6. Download `google-services.json` → `android/app/`
7. Download `GoogleService-Info.plist` → `ios/Runner/`
8. Update `firebase_options.dart` or remove it and let `flutterfire configure` regenerate

## Getting Started

```bash
# Install dependencies
flutter pub get

# iOS only: install CocoaPods
cd ios && pod install && cd ..

# Run the app
flutter run

# Analyze code
flutter analyze
```

## Firestore Collections

- `users/` - User profiles
- `trips/` - Trip details
- `expenses/` - Expense records
- `settlements/` - Balance settlements

## Project Status

This is an **architecture and backend foundation build** containing:

- Complete Firebase integration with service wrappers
- Error handling with custom exceptions
- Model serialization (fromJson/toJson)
- Riverpod state management with Firebase providers
- Material 3 theming (light + dark)
- GoRouter navigation with all route placeholders
- Reusable widget library
- Home screen dashboard
- Firebase initialization gateway with error screen

Business logic (authentication flows, trip CRUD, expense tracking, settlements, export) will be implemented in subsequent phases.

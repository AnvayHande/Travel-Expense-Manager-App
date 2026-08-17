import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/signup_screen.dart';
import '../../features/trip/presentation/screens/home_screen.dart';
import '../../features/trip/presentation/screens/create_trip_screen.dart';
import '../../features/trip/presentation/screens/join_trip_screen.dart';
import '../../features/trip/presentation/screens/trip_details_screen.dart';
import '../../features/trip/presentation/screens/participants_screen.dart';
import '../../features/expense/presentation/screens/expenses_screen.dart';
import '../../features/expense/presentation/screens/add_expense_screen.dart';
import '../../features/expense/presentation/screens/expense_details_screen.dart';
import '../../features/expense/presentation/screens/analytics_screen.dart';
import '../../features/settlement/presentation/screens/settlement_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/trip/presentation/screens/trip_settings_screen.dart';
import '../../features/export/presentation/screens/export_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/trip/presentation/screens/scan_qr_screen.dart';
import '../../features/trip/presentation/screens/trip_dashboard_screen.dart';
import '../../features/budget/presentation/screens/budget_dashboard_screen.dart';
import '../../features/budget/presentation/screens/category_management_screen.dart';
import '../../features/template/presentation/screens/template_management_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/report/presentation/screens/report_screen.dart';
import '../../features/ledger/presentation/screens/participant_ledger_screen.dart';
import '../../features/trip/presentation/screens/closing_wizard_screen.dart';
import '../../features/trip/presentation/screens/import_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/create-trip',
      name: 'createTrip',
      builder: (context, state) => const CreateTripScreen(),
    ),
    GoRoute(
      path: '/join-trip',
      name: 'joinTrip',
      builder: (context, state) => const JoinTripScreen(),
    ),
    GoRoute(
      path: '/scan-qr',
      name: 'scanQr',
      builder: (context, state) => const ScanQRScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId',
      name: 'tripDetails',
      builder: (context, state) => const TripDetailsScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/participants',
      name: 'participants',
      builder: (context, state) => const ParticipantsScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/expenses',
      name: 'expenses',
      builder: (context, state) => const ExpensesScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/add-expense',
      name: 'addExpense',
      builder: (context, state) => const AddExpenseScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/expense/:expenseId',
      name: 'expenseDetails',
      builder: (context, state) => const ExpenseDetailsScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/settlement',
      name: 'settlement',
      builder: (context, state) => const SettlementScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/analytics',
      name: 'analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/activity',
      name: 'activity',
      builder: (context, state) => const ActivityScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/settings',
      name: 'tripSettings',
      builder: (context, state) => const TripSettingsScreen(),
    ),
    GoRoute(
      path: '/trip/:tripId/dashboard',
        name: 'dashboard',
        builder: (context, state) => const TripDashboardScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/budget',
        name: 'budgetDashboard',
        builder: (context, state) => const BudgetDashboardScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/categories',
        name: 'categoryManagement',
        builder: (context, state) => const CategoryManagementScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/templates',
        name: 'templateManagement',
        builder: (context, state) => const TemplateManagementScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/insights',
        name: 'insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/report',
        name: 'report',
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/participant/:userId/ledger',
        name: 'participantLedger',
        builder: (context, state) => const ParticipantLedgerScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/import',
        name: 'import',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/close',
        name: 'closeTrip',
        builder: (context, state) => const ClosingWizardScreen(),
      ),
      GoRoute(
        path: '/export',
      name: 'export',
      builder: (context, state) => const ExportScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

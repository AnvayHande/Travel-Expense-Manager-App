import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'presentation/providers/firebase_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: FirebaseGateway(
        child: TripExpenseApp(),
      ),
    ),
  );
}

class FirebaseGateway extends ConsumerStatefulWidget {
  final Widget child;

  const FirebaseGateway({super.key, required this.child});

  @override
  ConsumerState<FirebaseGateway> createState() => _FirebaseGatewayState();
}

class _FirebaseGatewayState extends ConsumerState<FirebaseGateway> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(firebaseInitProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(firebaseInitProvider);

    switch (initState.status) {
      case FirebaseInitStatus.initializing:
        return _buildLoading();
      case FirebaseInitStatus.error:
        return _buildError(initState.errorMessage);
      case FirebaseInitStatus.initialized:
        return widget.child;
    }
  }

  Widget _buildLoading() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Initializing...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String? errorMessage) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1C1B1F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 80,
                  color: Colors.white54,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Firebase Not Configured',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please configure Firebase to use this app.\n'
                  'Run `flutterfire configure` in the project directory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(firebaseInitProvider.notifier).initialize();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

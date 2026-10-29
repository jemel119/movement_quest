import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/preferences_controller.dart';
import 'controllers/workout_controller.dart';
import 'data/app_database.dart';
import 'data/sqlite_training_log_repository.dart';
import 'data/sqlite_workout_repository.dart';
import 'repositories/preferences_repository.dart';
import 'repositories/shared_preferences_repository.dart';
import 'repositories/training_log_repository.dart';
import 'repositories/workout_repository.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MovementQuestStartup());
}

class MovementQuestStartup extends StatefulWidget {
  const MovementQuestStartup({super.key});

  @override
  State<MovementQuestStartup> createState() => _MovementQuestStartupState();
}

class _MovementQuestStartupState extends State<MovementQuestStartup> {
  late Future<SharedPreferences> _storageFuture;

  @override
  void initState() {
    super.initState();

    _storageFuture = _loadStorage();
  }

  Future<SharedPreferences> _loadStorage() {
    return SharedPreferences.getInstance().timeout(const Duration(seconds: 20));
  }

  void _retry() {
    setState(() {
      _storageFuture = _loadStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _storageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting Movement Quest...'),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              appBar: AppBar(title: const Text('Startup problem')),
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Movement Quest could not initialize local preferences.',
                  ),
                  const SizedBox(height: 16),
                  SelectableText(snapshot.error.toString()),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Retry startup'),
                  ),
                ],
              ),
            ),
          );
        }

        final storage = snapshot.data!;

        return MultiProvider(
          providers: [
            Provider<AppDatabase>(
              create: (_) => AppDatabase(),
              dispose: (_, database) => unawaited(database.close()),
            ),
            Provider<WorkoutRepository>(
              create: (context) =>
                  SqliteWorkoutRepository(context.read<AppDatabase>()),
            ),
            Provider<TrainingLogRepository>(
              create: (context) =>
                  SqliteTrainingLogRepository(context.read<AppDatabase>()),
            ),
            Provider<PreferencesRepository>(
              create: (_) => SharedPreferencesRepository(storage),
            ),
            ChangeNotifierProvider<WorkoutController>(
              create: (context) => WorkoutController(
                context.read<WorkoutRepository>(),
                context.read<TrainingLogRepository>(),
              ),
            ),
            ChangeNotifierProvider<PreferencesController>(
              create: (context) =>
                  PreferencesController(context.read<PreferencesRepository>()),
            ),
          ],
          child: const MovementQuestApp(),
        );
      },
    );
  }
}

class MovementQuestApp extends StatelessWidget {
  const MovementQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movement Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
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
    ),
  );
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

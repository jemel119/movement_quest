import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/workout_controller.dart';
import 'data/app_database.dart';
import 'data/sqlite_training_log_repository.dart';
import 'data/sqlite_workout_repository.dart';
import 'repositories/training_log_repository.dart';
import 'repositories/workout_repository.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
        ChangeNotifierProvider<WorkoutController>(
          create: (context) => WorkoutController(
            context.read<WorkoutRepository>(),
            context.read<TrainingLogRepository>(),
          ),
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

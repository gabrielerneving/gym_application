import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/master_exercise_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';

class ExerciseListScreen extends ConsumerWidget {
  final String category;
  const ExerciseListScreen({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dbService = DatabaseService(uid: uid);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text(category, style: TextStyle(color: theme.text)), 
        backgroundColor: theme.background,
      ),
      body: StreamBuilder<List<MasterExercise>>(
        stream: dbService.getMasterExercisesByCategory(category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.primary));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No exercises found in this category.', style: TextStyle(color: theme.text)));
          }

          final exercises = snapshot.data!;

          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return Card(
                color: theme.card,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
            side: BorderSide(
              color: theme.textSecondary.withOpacity(0.3), 
              width: 1,         
            ),
          ),
                child: ListTile(
                  title: Text(exercise.name, style: TextStyle(color: theme.text)),
                  onTap: () {
                    Navigator.of(context).pop(exercise);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
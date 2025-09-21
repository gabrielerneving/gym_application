import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/master_exercise_model.dart';
import '../services/database_service.dart';

class ExerciseListScreen extends StatelessWidget {
  final String category;
  const ExerciseListScreen({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dbService = DatabaseService(uid: uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(category), // Visa kategorinamnet
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<List<MasterExercise>>(
        stream: dbService.getMasterExercisesByCategory(category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No exercises found in this category.'));
          }

          final exercises = snapshot.data!;

          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return Card(
                color: Colors.grey.shade900,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // rundade hörn
            side: const BorderSide(
              color: Color(0xFF4D4D4D), // färgen på ramen
              width: 1,          // tjockleken på ramen
            ),
          ),
                child: ListTile(
                  title: Text(exercise.name, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    print('✅ TAPPED ON: ${exercise.name}. Popping with this value.');
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
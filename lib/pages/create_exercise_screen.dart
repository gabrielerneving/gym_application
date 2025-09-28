import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/master_exercise_model.dart';
import '../services/database_service.dart';

class CreateExerciseScreen extends StatefulWidget {
  const CreateExerciseScreen({Key? key}) : super(key: key);

  @override
  _CreateExerciseScreenState createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategory; // Håller reda på vald kategori
  bool _isLoading = false;

  final List<String> _categories = const [
    'Shoulders', 'Quads', 'Hamstrings', 'Glutes', 'Biceps', 'Triceps', 'Chest', 'Back', 'Abs', 'Cardio'
  ];

  Future<void> _saveExercise() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final newExercise = MasterExercise(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          category: _selectedCategory!,
        );

        await DatabaseService(uid: uid).saveMasterExercise(newExercise);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exercise saved!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Error handling kan läggas till här
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create exercise'),
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExercise,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Save', style: TextStyle(color: Colors.red, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                hint: const Text('Category'),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                items: _categories.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
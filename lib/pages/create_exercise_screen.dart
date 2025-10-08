import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/master_exercise_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';

class CreateExerciseScreen extends ConsumerStatefulWidget {
  const CreateExerciseScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends ConsumerState<CreateExerciseScreen> {
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
            const SnackBar(content: Text('Exercise saved and added to workout!')),
          );
          // Return the created exercise back to the previous screen
          Navigator.of(context).pop(newExercise);
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
    final theme = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Create exercise', style: TextStyle(color: theme.text)),
        backgroundColor: theme.background,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExercise,
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text('Save', style: TextStyle(color: theme.primary, fontSize: 16)),
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
                style: TextStyle(color: theme.text),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.textSecondary),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.primary),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                style: TextStyle(color: theme.text),
                dropdownColor: theme.card,
                hint: Text('Category', style: TextStyle(color: theme.textSecondary)),
                decoration: InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.textSecondary),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.primary),
                  ),
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                items: _categories.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: theme.text)),
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
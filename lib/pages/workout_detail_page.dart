import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_session_model.dart';

class WorkoutDetailPage extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutDetailPage({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFFDC2626).withOpacity(0.8), size: 24), // Subtil röd accent
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          session.programTitle,
          style: const TextStyle(
            color: Colors.white, // Tillbaka till vit
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false, // Android-stil, vänsterställd
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats card - Android Material style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12), // Mindre rundning
                border: Border.all(
                  color: const Color(0xFF2A2A2A),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(session.date),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '${session.durationInMinutes} min',
                      ),
                      _buildStatItem(
                        icon: Icons.fitness_center,
                        label: 'Exercises',
                        value: '${session.completedExercises.length}',
                      ),
                      _buildStatItem(
                        icon: Icons.repeat,
                        label: 'Working Sets',
                        value: '${session.completedExercises.fold<int>(0, (sum, ex) => sum + ex.sets.where((set) => !set.isWarmUp).length)}',
                      ),
                      _buildStatItem(
                        icon: Icons.local_fire_department,
                        label: 'Warm-up Sets',
                        value: '${session.completedExercises.fold<int>(0, (sum, ex) => sum + ex.sets.where((set) => set.isWarmUp).length)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Exercises list
            Text(
              'Exercises',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ...session.completedExercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade800.withOpacity(0.6),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise header
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626), // Din röda färg
                            borderRadius: BorderRadius.circular(8), // Lite mer rundning
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C...
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Sets list
                    ...exercise.sets.asMap().entries.map((setEntry) {
                      final setIndex = setEntry.key;
                      final set = setEntry.value;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Set number with warm-up indication
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: set.isWarmUp 
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: set.isWarmUp 
                                  ? Border.all(color: Colors.orange.withOpacity(0.4), width: 1)
                                  : null,
                              ),
                              child: Center(
                                child: set.isWarmUp
                                  ? Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 12,
                                    )
                                  : Text(
                                      '${setIndex + 1}',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Weight
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weight',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    set.weight > 0 ? '${set.weight} kg' : '-',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Reps
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reps',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    set.reps > 0 ? '${set.reps}' : '-',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Notes
                            if (set.notes != null && set.notes!.isNotEmpty)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notes',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      set.notes!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white, // Tillbaka till vit
          size: 26,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white, // Tillbaka till vit
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../utils/add_sample_templates.dart';

// Script för att lägga till templates via terminal
// Kör med: flutter run -t lib/scripts/add_templates.dart
void main() async {
  // Initiera Firebase
  await Firebase.initializeApp();
  
  debugPrint('🚀 Starting to add sample templates...');
  
  try {
    await addSampleTemplates();
    debugPrint('✅ Successfully added all sample templates!');
  } catch (e) {
    debugPrint('❌ Error: $e');
  }
  
  debugPrint('🏁 Done!');
}
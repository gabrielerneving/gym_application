import 'package:firebase_core/firebase_core.dart';
import '../utils/add_sample_templates.dart';

// Script för att lägga till templates via terminal
// Kör med: flutter run -t lib/scripts/add_templates.dart
void main() async {
  // Initiera Firebase
  await Firebase.initializeApp();
  
  print('🚀 Starting to add sample templates...');
  
  try {
    await addSampleTemplates();
    print('✅ Successfully added all sample templates!');
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('🏁 Done!');
}
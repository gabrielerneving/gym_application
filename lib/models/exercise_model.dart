class Exercise {
  String name;
  int sets; // Total sets (working + warm-up) för backward compatibility
  int workingSets; // Bara working sets som räknas i statistik
  int warmUpSets; // Warm-up sets som INTE räknas i statistik
  String id;

  Exercise({
    required this.name,
    required this.sets,
    required this.id,
    this.workingSets = 0,
    this.warmUpSets = 0,
  }) {
    // Om inte specificerat, anta att alla sets är working sets
    if (workingSets == 0 && warmUpSets == 0) {
      workingSets = sets;
    }
    // Säkerställ att total sets matchar
    sets = workingSets + warmUpSets;
  }
  
  // Factory constructor för att skapa en Exercise från en Map
  factory Exercise.fromMap(Map<String, dynamic> data) {
    return Exercise(
      id: data['id'] ?? '',
      name: data['name'] ?? 'No Name',
      sets: data['sets'] ?? 0,
      workingSets: data['workingSets'] ?? data['sets'] ?? 0, // Fallback till sets för backward compatibility
      warmUpSets: data['warmUpSets'] ?? 0,
    );
  }
  
  // Convert Exercise to Map för Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'workingSets': workingSets,
      'warmUpSets': warmUpSets,
    };
  }
}
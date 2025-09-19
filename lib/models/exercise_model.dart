class Exercise {
  String name;
  int sets;
  String id;

  Exercise({
    required this.name,
    required this.sets,
    required this.id,
  });
  // Factory constructor för att skapa en Exercise från en Map
  factory Exercise.fromMap(Map<String, dynamic> data) {
    return Exercise(
      id: data['id'] ?? '',
      name: data['name'] ?? 'No Name',
      sets: data['sets'] ?? 0,
    );
  }
}
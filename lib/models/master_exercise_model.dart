class MasterExercise {
  final String id;
  final String name;
  final String category;

  MasterExercise({
    required this.id,
    required this.name,
    required this.category,
  });

  // Från Firestore-data till ett objekt
  factory MasterExercise.fromFirestore(Map<String, dynamic> data) {
    return MasterExercise(
      id: data['id'],
      name: data['name'],
      category: data['category'],
    );
  }

  // Från ett objekt till Firestore-data
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }
}
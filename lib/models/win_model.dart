import 'package:cloud_firestore/cloud_firestore.dart';

class Win {
  final String id;
  final String title; // Changed from description to title
  final String category;
  final int effort;
  final DateTime timestamp;

  Win({
    required this.id,
    required this.title,
    required this.category,
    required this.effort,
    required this.timestamp,
  });

  // Factory to create a Win from Firestore data
  factory Win.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Win(
      id: doc.id,
      title: data['title'] ?? data['description'] ?? '', // Fallback for old data
      category: data['category'] ?? 'General',
      effort: data['effort'] ?? 1,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // Convert Win to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'effort': effort,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
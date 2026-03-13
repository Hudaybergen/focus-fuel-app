import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/win_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // This getter ensures we ALWAYS get the current user's ID
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  // Add a win - strictly tied to this UID
  Future<void> addWin(String text, String category, int effort) async {
    await _db.collection('wins').add({
      'text': text,
      'category': category,
      'effort': effort,
      'uid': uid, // The secret sauce for multi-user apps
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Delete a specific win using its unique Document ID
  Future<void> deleteWin(String docId) async {
    try {
      await _db.collection('wins').doc(docId).delete();
      debugPrint("Win deleted successfully: $docId");
    } catch (e) {
      debugPrint("Error deleting win: $e");
    }
  }

  // Get wins - strictly FILTERED by this UID
  Stream<List<Win>> get winsStream {
    return _db
        .collection('wins')
        .where('uid', isEqualTo: uid) // Only show MY data
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Win.fromFirestore(doc)).toList());
  }

// Get the individual user's profile/mission
  Stream<DocumentSnapshot> get userProfileStream {
    return _db.collection('users').doc(uid).snapshots();
  }

// Fetch the user's custom categories
  Stream<List<String>> get categoriesStream {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('categories')) {
        return List<String>.from(snapshot.data()!['categories']);
      }
      // Default categories if they haven't customized yet
      return ['Study', 'Coding', 'Fitness', 'Mindset'];
    });
  }

// Stream to get the user's profile document (name, photoUrl, etc.)
  Stream<DocumentSnapshot> get userDocStream {
    return _db.collection('users').doc(uid).snapshots();
  }

// Method to update profile details
  // Ensure the curly braces { } are present around the parameters!
  Future<void> updateUserData(
      {String? name, String? photoUrl, String? purpose}) async {
    Map<String, dynamic> data = {};

    if (name != null) data['displayName'] = name;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (purpose != null) data['purpose'] = purpose;

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

// Update the category list
  Future<void> updateCategories(List<String> newCategories) async {
    await _db.collection('users').doc(uid).set({
      'categories': newCategories,
    }, SetOptions(merge: true));
  }

  // Edit a win
  // Update the text of an existing win
  Future<void> updateWin(String docId, String newText) async {
    await _db.collection('wins').doc(docId).update({
      'text': newText,
    });
  }

  // Save or Update a user's custom mission/purpose
  Future<void> setUserPurpose(String purpose) async {
    try {
      // We store this in a 'users' collection using the unique UID
      await _db.collection('users').doc(uid).set(
          {
            'purpose': purpose,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(
              merge:
                  true)); // 'merge' ensures we don't delete other profile info
      debugPrint("Purpose updated successfully for user: $uid");
    } catch (e) {
      debugPrint("Error updating purpose: $e");
    }
  }

  // Calculate the current win streak
  int calculateStreak(List<Win> wins) {
    if (wins.isEmpty) return 0;

    int streak = 0;
    DateTime today = DateTime.now();
    DateTime currentCheckDate = DateTime(today.year, today.month, today.day);

    // Get a list of unique days where wins occurred (sorted newest to oldest)
    List<DateTime> winDays = wins
        .map((w) =>
            DateTime(w.timestamp.year, w.timestamp.month, w.timestamp.day))
        .toSet()
        .toList();

    winDays.sort((a, b) => b.compareTo(a));

    // If the latest win wasn't today or yesterday, the streak is broken
    if (winDays.first
        .isBefore(currentCheckDate.subtract(const Duration(days: 1)))) {
      return 0;
    }

    // If the latest win was yesterday but not today, we start checking from yesterday
    if (winDays.first == currentCheckDate.subtract(const Duration(days: 1))) {
      currentCheckDate = winDays.first;
    }

    for (DateTime day in winDays) {
      if (day == currentCheckDate) {
        streak++;
        currentCheckDate = currentCheckDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // Send a password reset email to the user
  Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      debugPrint("Error sending reset email: $e");
      rethrow; // Pass the error back to the UI to show the user
    }
  }
}

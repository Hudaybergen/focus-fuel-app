import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_services.dart';
import '../models/win_model.dart';

class ProfileScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const ProfileScreen({super.key, required this.onThemeChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _db = DatabaseService();

  // --- EDIT NAME DIALOG (Properly Referenced) ---
  void _showEditNameDialog(BuildContext context, String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Profile"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: "Full Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              // Use the unified updateUserData method
              await _db.updateUserData(name: nameController.text.trim());
              
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Growth & Settings")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.userDocStream, // Unified stream for name, photo, purpose
        builder: (context, userSnap) {
          // Default values if document doesn't exist yet
          String displayName = "User";
          String? photoUrl;
          
          if (userSnap.hasData && userSnap.data!.exists) {
            final data = userSnap.data!.data() as Map<String, dynamic>;
            displayName = data['displayName'] ?? "User";
            photoUrl = data['photoUrl'];
          }

          return StreamBuilder<List<Win>>(
            stream: _db.winsStream,
            builder: (context, winSnap) {
              final wins = winSnap.data ?? [];
              int totalWins = wins.length;
              double avgEffort = totalWins == 0 
                  ? 0 
                  : wins.map((w) => w.effort).reduce((a, b) => a + b) / totalWins;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 1. DYNAMIC HEADER
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.orange.shade100,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null 
                          ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(user?.email ?? "", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    
                    // The Pencil Icon Button to trigger the dialog
                    TextButton.icon(
                      onPressed: () => _showEditNameDialog(context, displayName),
                      icon: const Icon(Icons.edit, size: 16, color: Colors.orange),
                      label: const Text("Edit Name", style: TextStyle(color: Colors.orange)),
                    ),
                    
                    const SizedBox(height: 24),

                    // 2. STATS DASHBOARD
                    Row(
                      children: [
                        _buildStatCard("Total Wins", totalWins.toString(), Colors.orange),
                        _buildStatCard("Avg Effort", avgEffort.toStringAsFixed(1), Colors.deepOrange),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 3. PREFERENCES
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("PREFERENCES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 10),
                    
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined, color: Colors.orange),
                        title: const Text("Dark Mode"),
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (bool value) => widget.onThemeChanged(value),
                      ),
                    ),

                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.category_outlined, color: Colors.orange),
                        title: const Text("Edit My Categories"),
                        onTap: () => _showCategoryEditor(context),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 4. ACCOUNT ACTIONS
                    const Divider(),
                    TextButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  // --- CATEGORY EDITOR DIALOG ---
  void _showCategoryEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<List<String>>(
          stream: _db.categoriesStream,
          builder: (context, snapshot) {
            List<String> categories = snapshot.data ?? ['Study', 'Coding', 'Fitness', 'Mindset'];
            TextEditingController addController = TextEditingController();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Inside _showCategoryEditor...
const Text("Manage Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 15),

// 1. Wrap the ListView in a SizedBox or ConstrainedBox
SizedBox(
  height: 250, // Set the fixed height here
  child: ListView(
    shrinkWrap: true,
    children: categories.map((cat) => ListTile(
      title: Text(cat),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        onPressed: () async {
          categories.remove(cat);
          await _db.updateCategories(categories);
        },
      ),
    )).toList(),
  ),
),

                  TextField(
                    controller: addController,
                    decoration: InputDecoration(
                      hintText: "Add new category...",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add, color: Colors.green),
                        onPressed: () async {
                          if (addController.text.isNotEmpty) {
                            final newCat = addController.text;
                            categories.add(newCat);
                            await _db.updateCategories(categories);
                            if (!context.mounted) return;
                            addController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
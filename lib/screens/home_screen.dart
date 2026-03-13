import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_services.dart';
import '../models/win_model.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // late final allows widget.onThemeChanged to be accessed safely
  late final List<Widget> _pages = [
    const HomeContent(),
    ProfileScreen(onThemeChanged: widget.onThemeChanged),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.orange.shade800,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: "Focus"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// --- MAIN DASHBOARD CONTENT ---

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();

  String selectedCategory = 'Study';
  double _willpowerEffort = 5.0;

  Color _getEffortColor(int effort) {
    if (effort <= 3) return Colors.green;
    if (effort <= 7) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Coding':
        return Icons.code;
      case 'Study':
        return Icons.menu_book;
      case 'Fitness':
        return Icons.fitness_center;
      case 'Mindset':
        return Icons.psychology;
      default:
        return Icons.stars;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔥 Focus Fuel")),
      body: Column(
        children: [
          _buildMissionHeader(),
          _buildCategorySelector(),
          _buildInputField(),
          const Divider(),
          _buildWinList(),
        ],
      ),
    );
  }

  Widget _buildMissionHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.userDocStream, // Using our unified stream
      builder: (context, snapshot) {
        String purpose = "Set your daily focus...";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          purpose = data['purpose'] ?? purpose;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade700]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MY MISSION",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  StreamBuilder<List<Win>>(
                    stream: _db.winsStream,
                    builder: (context, winSnap) {
                      // Note: Ensure calculateStreak is defined in DatabaseService
                      int streak = _db.calculateStreak(winSnap.data ?? []);
                      return Row(
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Colors.orangeAccent, size: 16),
                          Text(" $streak DAY STREAK",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(purpose,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    onPressed: () => _showPurposeDialog(purpose),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    return StreamBuilder<List<String>>(
        stream: _db.categoriesStream,
        builder: (context, snapshot) {
          final userCategories =
              snapshot.data ?? ['Study', 'Coding', 'Fitness', 'Mindset'];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: userCategories
                  .map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: selectedCategory == cat,
                          onSelected: (selected) =>
                              setState(() => selectedCategory = cat),
                        ),
                      ))
                  .toList(),
            ),
          );
        });
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "New win in $selectedCategory...",
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.orange),
                // --- CONNECT THE FUNCTION HERE ---
                onPressed: _saveWin,
              ),
            ),
          ),
          Slider(
            value: _willpowerEffort,
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: _getEffortColor(_willpowerEffort.toInt()),
            onChanged: (val) => setState(() => _willpowerEffort = val),
          ),
        ],
      ),
    );
  }

  void _saveWin() async {
    if (_controller.text.trim().isNotEmpty) {
      // Save to Firebase
      await _db.addWin(
          _controller.text.trim(), selectedCategory, _willpowerEffort.toInt());

      // Check if user is still on this screen before touching UI
      if (!mounted) return;

      _controller.clear();
      FocusScope.of(context).unfocus(); // Hides keyboard
    }
  }

  Widget _buildWinList() {
    return Expanded(
      child: StreamBuilder<List<Win>>(
        stream: _db.winsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wins = snapshot.data!;
          if (wins.isEmpty) {
            return const Center(
                child: Text("No wins yet. Start your mission!"));
          }

          return ListView.builder(
            itemCount: wins.length,
            itemBuilder: (context, index) {
              final win = wins[index];
              final color = _getEffortColor(win.effort);

              return Dismissible(
                key: Key(win.id),
                direction: DismissDirection.endToStart,
                // ... (keep your existing confirmDismiss logic)
                onDismissed: (_) => _db.deleteWin(win.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Icon(_getCategoryIcon(win.category), color: color),
                    // --- TASK NAME (The Title) ---
                    title: Text(
                      win.title, // This is your task name
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    // --- DETAILS (Category & Time) ---
                    subtitle: Text(
                      "${win.category} • ${win.timestamp.toString().substring(11, 16)}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "🔥 ${win.effort}",
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPurposeDialog(String currentPurpose) {
    TextEditingController pController =
        TextEditingController(text: currentPurpose);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Mission"),
        content: TextField(controller: pController, autofocus: true),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Using unified updateUserData method
              await _db.updateUserData(purpose: pController.text.trim());

              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

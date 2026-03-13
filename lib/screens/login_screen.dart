import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  bool _isLogin = true; // Toggle between Login and Sign Up
  bool _isLoading = false;

  // --- AUTH LOGIC ---
  // Example fix for _handleAuth in login_screen.dart
  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      // --- ADD THIS CHECK HERE ---
      if (!mounted) return;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return; // Also check here before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication failed")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FORGOT PASSWORD DIALOG ---
  void _showResetPasswordDialog() {
    TextEditingController resetController = TextEditingController();
    bool isSending = false; // Internal state for the dialog

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Reset Password"),
            content: isSending
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()))
                : TextField(
                    controller: resetController,
                    decoration:
                        const InputDecoration(hintText: "Enter your email"),
                    keyboardType: TextInputType.emailAddress,
                  ),
            actions: isSending
                ? [] // Hide buttons while sending
                : [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    ElevatedButton(
                      onPressed: () async {
                        if (resetController.text.trim().isEmpty) return;

                        // Start loading
                        setDialogState(() => isSending = true);

                        try {
                          await _db
                              .sendPasswordReset(resetController.text.trim());

                          if (!context.mounted) return;

                          Navigator.pop(context); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Reset email sent!")),
                          );
                        } catch (e) {
                          if (!context.mounted) return;

                          // Stop loading to show the error
                          setDialogState(() => isSending = false);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Error: Check email format")),
                          );
                        }
                      },
                      child: const Text("Send"),
                    ),
                  ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. BRANDING HEADER
              const Icon(Icons.bolt, size: 80, color: Colors.orange),
              const Text(
                "FOCUS FUEL",
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2),
              ),
              const Text(
                "Prime your brain for success.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 40),

              // 2. INPUT FIELDS
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: "Email", border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                    labelText: "Password", border: OutlineInputBorder()),
                obscureText: true,
              ),

              // 3. FORGOT PASSWORD LINK
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showResetPasswordDialog,
                  child: const Text("Forgot Password?",
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
              ),

              const SizedBox(height: 20),

              // 4. ACTION BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _handleAuth,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? "LOGIN" : "SIGN UP"),
                ),
              ),

              // 5. TOGGLE LOGIN/SIGNUP
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? "New here? Create an account"
                      : "Already have an account? Login",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

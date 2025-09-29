import 'dart:math';

import 'package:fitness/auth/auth_service.dart';
import 'package:fitness/pages/coach.dart';
import 'package:fitness/pages/profile.dart';
import 'package:fitness/pages/profile_user.dart';
import 'package:fitness/pages/register.dart';
import 'package:fitness/pages/verification.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://dbxaqntkbcbypbwkuwti.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRieGFxbnRrYmNieXBid2t1d3RpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyOTE2NzIsImV4cCI6MjA3Mzg2NzY3Mn0.zO7iOg73eW5P5V5-eER_vP-jdoSwFgypH-gV0tzdUu0',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for login form
  final supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isCoach = false;
  final authService = AuthService();
  bool isVerified = false;

  void login() async {
    final email = emailController.text;
    final password = passwordController.text;

    try {
      await authService.signInWithEmailPassword(email, password);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        print("No logged-in user!");
        return;
      }

      final response = await supabase
          .from('profiles')
          .select('isVerified, role')
          .eq('id', userId);

      if (response.isNotEmpty) {
        isVerified = response[0]['isVerified'] as bool;
        final role = response[0]['role'] as String?;
        print('User verified: $isVerified');
        print('User role: $role');

        if (role == "coach") {
          // Redirect coach to coachPage
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CoachPage()),
          );
        } else if (isVerified) {
          // Student but verified
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileUser()),
          );
        } else {
          // Student but not verified
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GesturePage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8E3C9), // light green background
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8E3C9),
        elevation: 0,
        title: const Text("Login Page", style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                "WELCOME TO GAMECHANGER!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("'Play Fair'", style: TextStyle(fontSize: 17)),
              const SizedBox(height: 40),
              ToggleButtons(
                isSelected: [!isCoach, isCoach],
                onPressed: (index) {
                  setState(() {
                    isCoach = index == 1;
                  });
                },
                borderRadius: BorderRadius.circular(40),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text("Student"),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text("Coach"),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Email TextField
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Password TextField
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 30),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFAECF9F), // green button
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Footer Text
              if (!isCoach) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Not a Member? Register Now",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

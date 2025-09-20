import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnaylzePage extends StatefulWidget {
  const AnaylzePage({super.key});

  @override
  State<AnaylzePage> createState() => _AnaylzePageState();
}

class _AnaylzePageState extends State<AnaylzePage> {
  final supabase = Supabase.instance.client;
  double score = 0;

  Future<void> updateScore() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      print("No user logged in");
      return;
    }

    try {
      final data = await supabase
          .from('profiles')
          .select('pushups, squats, gender, height, weight, age')
          .eq('id', user.id)
          .single();

      print("Fetched data: $data");

      double pushups = (data['pushups'] ?? 0).toDouble();
      double squats = (data['squats'] ?? 0).toDouble();
      double gender = (data['gender'] == 'male') ? 1.0 : 1.5;
      double height = (data['height'] ?? 0).toDouble();
      double weight = (data['weight'] ?? 0).toDouble();
      double age = (data['age'] ?? 0).toDouble();

      if (pushups == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Do PUSHUPS")));
      } else if (squats == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Do SQUATS")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Do PUSHUPS and SQUATS")));
      }

      // ✅ Update state variable (not local)
      setState(() {
        score =
            (((squats) * pow(weight, 0.4)) /
                ((pow(age, 0.3)) * pow(height, 0.3))) *
            gender;
      });

      print("Score: $score");

      await supabase
          .from('profiles')
          .update({'score': score})
          .eq('id', user.id);

      print("✅ Score updated");
    } catch (e) {
      print('Error fetching exercises: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    updateScore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Analyze Page")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Your Score is $score", style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

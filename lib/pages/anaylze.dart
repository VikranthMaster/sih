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
      final response = await supabase
          .from('profiles')
          .select(
            'pushups, squats, gender, height, weight, age',
          ) // select only these two columns
          .eq('id', user.id)
          .single(); // only one row expected

      final data = response;
      double pushups = (data['pushups'] ?? 0).toDouble();
      double squats = (data['squats'] ?? 0).toDouble();
      double gender = data['gender'] == 'male' ? 1.0 : 1.5;
      double height = (data['height'] ?? 0).toDouble();
      double weight = (data['weight'] ?? 0).toDouble();
      double age = (data['age'] ?? 0).toDouble();

      if ((pushups == 0 || pushups == null)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Do PUSHUPS")));
      } else if ((squats == 0 || squats == null)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Do SQUATS")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Do PUSHUPS and SQUATS")));
      }

      score =
          (((squats) * (pow(height, 0.4))) / ((age) * pow(height, 0.4))) *
          gender;

      print(score);

      final something = await supabase
          .from('profiles')
          .update({'score': score})
          .eq('id', user.id)
          .select()
          .single();
      print("Pushed to score");
    } catch (e) {
      print('Error fetching exercises: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    updateScore();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Analyze Page")),
      body: Center(
        child: Column(
          children: [
            Text("Your Score is $score", style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

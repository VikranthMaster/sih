import 'package:fitness/auth/auth_service.dart';
import 'package:fitness/pages/verification.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  void logout() async {
    await authService.signOut();
    Navigator.pop(context);
  }

  Future<String?> getCurrentName() async {
    final session = _supabase.auth.currentUser;
    if (session == null) return null;
    final response = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', session.id)
        .single();
    return response['full_name'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Page"),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(70.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FutureBuilder<String?>(
              future: getCurrentName(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  final name = snapshot.data ?? 'Guest';
                  return Text(
                    'Hello, $name!',
                    style: const TextStyle(fontSize: 24),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            Text("To Get Verified Click on the Below Button"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Verification()),
                );
              },
              child: Text("Primary Test", style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String aadhar,
    double? height,
    double? weight,
    required bool isCoach,
    required String gender,
    required int? age,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      await _supabase.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'full_name': fullName,
        'role': isCoach ? 'coach' : 'student',
        'height': height,
        'weight': weight,
        'gender': gender,
        'aadhar_number': aadhar,
        'age': age,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      throw Exception("User signup failed");
    }
  }

  Future<void> addVerification(bool verf) async {
    final supabase = Supabase.instance.client;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print("No logged-in user!");
      return;
    }

    try {
      // Update row
      await supabase
          .from('profiles')
          .update({'isVerified': verf})
          .eq('id', userId);

      print("Verification updated successfully!");
    } catch (e) {
      print("Error updating verification: $e");
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

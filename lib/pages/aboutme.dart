import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Aboutme extends StatefulWidget {
  const Aboutme({super.key});

  @override
  State<Aboutme> createState() => _AboutmeState();
}

class _AboutmeState extends State<Aboutme> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // User profile data
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  String? error;
  bool isEditing = false;

  // Controllers for editing
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();

  String selectedGender = 'male';
  String selectedRole = 'student';

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _aadharController.dispose();
    super.dispose();
  }

  Future<void> fetchUserProfile() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          userProfile = response;
          _populateControllers();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) {
        setState(() {
          error = 'Failed to load profile';
          isLoading = false;
        });
      }
    }
  }

  void _populateControllers() {
    if (userProfile != null) {
      _fullNameController.text = userProfile!['full_name']?.toString() ?? '';
      _heightController.text = userProfile!['height']?.toString() ?? '';
      _weightController.text = userProfile!['weight']?.toString() ?? '';
      _aadharController.text = userProfile!['aadhar_number']?.toString() ?? '';
      selectedGender = userProfile!['gender']?.toString() ?? 'male';
      selectedRole = userProfile!['role']?.toString() ?? 'student';
    }
  }

  Future<void> updateProfile() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final updates = {
        'full_name': _fullNameController.text.trim(),
        'height': double.tryParse(_heightController.text),
        'weight': double.tryParse(_weightController.text),
        'aadhar_number': _aadharController.text.trim(),
        'gender': selectedGender,
        'role': selectedRole,
      };

      await _supabase.from('profiles').update(updates).eq('id', user.id);

      await fetchUserProfile();

      if (mounted) {
        setState(() => isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple, Colors.deepPurple.shade700],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 50, color: Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          Text(
            userProfile?['full_name']?.toString() ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (userProfile?['role']?.toString() ?? 'student').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (userProfile?['score'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '${userProfile!['score']} points',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.deepPurple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.deepPurple),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.deepPurple),
            ),
          ),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option.toUpperCase()),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEditingView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEditableField(
            label: 'Full Name',
            controller: _fullNameController,
          ),
          _buildEditableField(
            label: 'Height',
            controller: _heightController,
            keyboardType: TextInputType.number,
            suffix: 'cm',
          ),
          _buildEditableField(
            label: 'Weight',
            controller: _weightController,
            keyboardType: TextInputType.number,
            suffix: 'kg',
          ),
          _buildEditableField(
            label: 'Aadhar Number',
            controller: _aadharController,
            keyboardType: TextInputType.number,
          ),
          _buildDropdownField(
            label: 'Gender',
            value: selectedGender,
            options: ['male', 'female', 'other'],
            onChanged: (value) {
              setState(() => selectedGender = value ?? 'male');
            },
          ),
          _buildDropdownField(
            label: 'Role',
            value: selectedRole,
            options: ['student', 'teacher', 'admin'],
            onChanged: (value) {
              setState(() => selectedRole = value ?? 'student');
            },
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      isEditing = false;
                      _populateControllers();
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            icon: Icons.email,
            title: 'Email',
            value: userProfile?['email']?.toString() ?? 'Not provided',
          ),
          _buildInfoCard(
            icon: Icons.height,
            title: 'Height',
            value: userProfile?['height'] != null
                ? '${userProfile!['height']} cm'
                : 'Not provided',
          ),
          _buildInfoCard(
            icon: Icons.monitor_weight,
            title: 'Weight',
            value: userProfile?['weight'] != null
                ? '${userProfile!['weight']} kg'
                : 'Not provided',
          ),
          _buildInfoCard(
            icon: Icons.person_outline,
            title: 'Gender',
            value: (userProfile?['gender']?.toString() ?? 'Not specified')
                .toUpperCase(),
          ),
          _buildInfoCard(
            icon: Icons.credit_card,
            title: 'Aadhar Number',
            value: userProfile?['aadhar_number']?.toString() ?? 'Not provided',
          ),
          if (userProfile?['isVerified'] != null)
            _buildInfoCard(
              icon: userProfile!['isVerified'] ? Icons.verified : Icons.warning,
              title: 'Verification Status',
              value: userProfile!['isVerified'] ? 'Verified' : 'Not Verified',
              valueColor: userProfile!['isVerified']
                  ? Colors.green
                  : Colors.orange,
            ),
          if (userProfile?['created_at'] != null) ...[
            const SizedBox(height: 16),
            Text(
              'Member since ${DateTime.parse(userProfile!['created_at']).year}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'About Me',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!isEditing && !isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (!isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: fetchUserProfile,
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile...'),
                ],
              ),
            )
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(fontSize: 16, color: Colors.red[700]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: fetchUserProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 20),
                    isEditing ? _buildEditingView() : _buildViewMode(),
                  ],
                ),
              ),
            ),
    );
  }
}

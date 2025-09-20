import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  String? error;
  String? currentUserId;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeLeaderboard();
  }

  Future<void> _initializeLeaderboard() async {
    try {
      // Get current user ID safely
      final user = _supabase.auth.currentUser;
      currentUserId = user?.id;

      // Fetch initial data
      await fetchLeaderboard();

      // Setup realtime subscription
      setupRealtimeLeaderboard();
    } catch (e) {
      debugPrint('Error initializing leaderboard: $e');
      if (mounted) {
        setState(() {
          error = 'Failed to initialize leaderboard';
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Safely unsubscribe from realtime updates
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchLeaderboard() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, score, role')
          .eq('role', 'student')
          .order('score', ascending: false);

      if (mounted) {
        setState(() {
          users = List<Map<String, dynamic>>.from(response);
          isLoading = false;
          error = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = 'Failed to load leaderboard. Please try again.';
        });
      }
    }
  }

  void setupRealtimeLeaderboard() {
    try {
      _subscription = _supabase
          .channel('leaderboard_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'role',
              value: 'student',
            ),
            callback: (payload) {
              debugPrint('Realtime update received: ${payload.eventType}');
              // Debounce rapid updates
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  fetchLeaderboard();
                }
              });
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
      // Continue without realtime updates if subscription fails
    }
  }

  Color getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber[600] ?? Colors.amber; // Gold
      case 1:
        return Colors.grey[600] ?? Colors.grey; // Silver
      case 2:
        return Colors.brown[600] ?? Colors.brown; // Bronze
      default:
        return Colors.deepPurple;
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            error ?? 'An error occurred',
            style: TextStyle(fontSize: 16, color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchLeaderboard,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No students found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to join the leaderboard!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : fetchLeaderboard,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: fetchLeaderboard, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (error != null) {
      return _buildErrorWidget();
    }

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading leaderboard...'),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (users.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurple[100]!),
              ),
              child: Text(
                '${users.length} student${users.length == 1 ? '' : 's'} competing',
                style: TextStyle(
                  color: Colors.deepPurple[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isCurrentUser = user['id'] == currentUserId;
                final score = user['score'];
                final fullName = user['full_name'];

                return Card(
                  color: isCurrentUser ? Colors.deepPurple[50] : Colors.white,
                  elevation: isCurrentUser ? 8 : 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isCurrentUser
                        ? BorderSide(color: Colors.deepPurple[200]!, width: 2)
                        : BorderSide.none,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: getRankColor(index),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName?.toString().trim().isNotEmpty == true
                                ? fullName.toString()
                                : 'Anonymous User',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrentUser
                                  ? Colors.deepPurple
                                  : Colors.black,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${score?.toString() ?? '0'} pts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: getRankColor(index),
                            fontSize: 16,
                          ),
                        ),
                        if (index < 3) ...[
                          const SizedBox(height: 2),
                          Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: getRankColor(index),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

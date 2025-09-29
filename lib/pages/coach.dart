// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:video_player/video_player.dart';

// class CoachPage extends StatefulWidget {
//   const CoachPage({super.key});

//   @override
//   State<CoachPage> createState() => _CoachPageState();
// }

// class _CoachPageState extends State<CoachPage> {
//   final supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> videos = [];
//   List<Map<String, dynamic>> profiles = [];
//   bool isLoading = true;
//   String? selectedUserId;
//   final TextEditingController _scoreController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     setState(() => isLoading = true);

//     try {
//       // Load videos from storage
//       final videoFiles = await supabase.storage.from('videos').list();

//       // Load user profiles
//       final profileData = await supabase
//           .from('profiles')
//           .select('*')
//           .order('created_at', ascending: false);

//       setState(() {
//         videos = videoFiles
//             .map(
//               (file) => {
//                 'name': file.name,
//                 'url': supabase.storage.from('videos').getPublicUrl(file.name),
//                 'updated_at': file.updatedAt,
//               },
//             )
//             .toList();

//         profiles = List<Map<String, dynamic>>.from(profileData);
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
//     }
//   }

//   Future<void> _updateScore(String userId, double score) async {
//     try {
//       await supabase.from('profiles').update({'score': score}).eq('id', userId);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Score updated successfully!')),
//       );

//       _loadData(); // Refresh data
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error updating score: $e')));
//     }
//   }

//   void _showScoreDialog(Map<String, dynamic> profile) {
//     _scoreController.text = profile['score']?.toString() ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Update Score for ${profile['full_name']}'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Current Score: ${profile['score'] ?? 'Not set'}'),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: _scoreController,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(
//                   labelText: 'New Score',
//                   border: OutlineInputBorder(),
//                   suffixText: 'pts',
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final score = double.tryParse(_scoreController.text);
//                 if (score != null) {
//                   _updateScore(profile['id'], score);
//                   Navigator.of(context).pop();
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please enter a valid score')),
//                   );
//                 }
//               },
//               child: const Text('Update'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Coach Dashboard'),
//         backgroundColor: Theme.of(context).primaryColor,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : DefaultTabController(
//               length: 2,
//               child: Column(
//                 children: [
//                   Container(
//                     color: Theme.of(context).primaryColor,
//                     child: const TabBar(
//                       indicatorColor: Colors.white,
//                       labelColor: Colors.white,
//                       unselectedLabelColor: Colors.white70,
//                       tabs: [
//                         Tab(icon: Icon(Icons.video_library), text: 'Videos'),
//                         Tab(icon: Icon(Icons.people), text: 'Athletes'),
//                       ],
//                     ),
//                   ),
//                   Expanded(
//                     child: TabBarView(
//                       children: [_buildVideosTab(), _buildAthletesTab()],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildVideosTab() {
//     return videos.isEmpty
//         ? const Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.video_library_outlined,
//                   size: 64,
//                   color: Colors.grey,
//                 ),
//                 SizedBox(height: 16),
//                 Text(
//                   'No videos found',
//                   style: TextStyle(fontSize: 18, color: Colors.grey),
//                 ),
//               ],
//             ),
//           )
//         : GridView.builder(
//             padding: const EdgeInsets.all(16),
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2,
//               childAspectRatio: 16 / 10,
//               crossAxisSpacing: 16,
//               mainAxisSpacing: 16,
//             ),
//             itemCount: videos.length,
//             itemBuilder: (context, index) {
//               final video = videos[index];
//               return _buildVideoCard(video);
//             },
//           );
//   }

//   Widget _buildVideoCard(Map<String, dynamic> video) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () => _showVideoOptions(video),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.grey[200],
//                   borderRadius: const BorderRadius.vertical(
//                     top: Radius.circular(12),
//                   ),
//                 ),
//                 child: const Icon(
//                   Icons.play_circle_filled,
//                   size: 48,
//                   color: Colors.blue,
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     video['name'],
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Tap to view options',
//                     style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAthletesTab() {
//     return profiles.isEmpty
//         ? const Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.people_outlined, size: 64, color: Colors.grey),
//                 SizedBox(height: 16),
//                 Text(
//                   'No athletes found',
//                   style: TextStyle(fontSize: 18, color: Colors.grey),
//                 ),
//               ],
//             ),
//           )
//         : ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: profiles.length,
//             itemBuilder: (context, index) {
//               final profile = profiles[index];
//               return _buildAthleteCard(profile);
//             },
//           );
//   }

//   Widget _buildAthleteCard(Map<String, dynamic> profile) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             CircleAvatar(
//               radius: 30,
//               backgroundColor: Colors.blue.shade100,
//               child: Text(
//                 profile['full_name']
//                         ?.toString()
//                         .substring(0, 1)
//                         .toUpperCase() ??
//                     'A',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.blue.shade800,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     profile['full_name'] ?? 'Unknown',
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 2,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.grey[200],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       'ID: ${profile['id'] ?? 'N/A'}',
//                       style: TextStyle(
//                         color: Colors.grey[700],
//                         fontSize: 12,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Age: ${profile['age'] ?? 'N/A'} | Role: ${profile['role'] ?? 'N/A'}',
//                     style: TextStyle(color: Colors.grey[600], fontSize: 14),
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.fitness_center,
//                         size: 16,
//                         color: Colors.grey[600],
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         'Pushups: ${profile['pushups'] ?? 0} | Squats: ${profile['squats'] ?? 0}',
//                         style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _getScoreColor(profile['score']),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     'Score: ${profile['score']?.toString() ?? 'Not set'}',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ElevatedButton.icon(
//                   onPressed: () => _showScoreDialog(profile),
//                   icon: const Icon(Icons.edit, size: 16),
//                   label: const Text('Update'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showVideoPlayer(Map<String, dynamic> video) {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) =>
//             VideoPlayerScreen(videoUrl: video['url'], title: video['name']),
//       ),
//     );
//   }

//   Color _getScoreColor(dynamic score) {
//     if (score == null) return Colors.grey;
//     final scoreValue = double.tryParse(score.toString()) ?? 0;
//     if (scoreValue >= 80) return Colors.green;
//     if (scoreValue >= 60) return Colors.orange;
//     return Colors.red;
//   }

//   void _showVideoOptions(Map<String, dynamic> video) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (BuildContext context) {
//         return Container(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 video['name'],
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 20),
//               ListTile(
//                 leading: const Icon(Icons.play_arrow),
//                 title: const Text('Play in App'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _showVideoPlayer(video);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.link),
//                 title: const Text('Copy Video URL'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _copyToClipboard(video['url']);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.download),
//                 title: const Text('Download Video'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _downloadVideo(video);
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _copyToClipboard(String url) {
//     // You'll need to add clipboard package to pubspec.yaml
//     // Clipboard.setData(ClipboardData(text: url));
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Video URL copied to clipboard')),
//     );
//   }

//   void _downloadVideo(Map<String, dynamic> video) {
//     // Implement download functionality if needed
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Download started for ${video['name']}')),
//     );
//   }

//   @override
//   void dispose() {
//     _scoreController.dispose();
//     super.dispose();
//   }
// }

// class VideoPlayerScreen extends StatefulWidget {
//   final String videoUrl;
//   final String title;

//   const VideoPlayerScreen({
//     super.key,
//     required this.videoUrl,
//     required this.title,
//   });

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   VideoPlayerController? _controller;
//   bool _isInitialized = false;
//   bool _hasError = false;
//   String _errorMessage = '';

//   @override
//   void initState() {
//     super.initState();
//     _initializePlayer();
//   }

//   Future<void> _initializePlayer() async {
//     try {
//       // Add headers for better compatibility
//       _controller = VideoPlayerController.networkUrl(
//         Uri.parse(widget.videoUrl),
//         httpHeaders: {'User-Agent': 'Mozilla/5.0 (compatible)'},
//       );

//       await _controller!.initialize();

//       if (mounted) {
//         setState(() {
//           _isInitialized = true;
//           _hasError = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _hasError = true;
//           _errorMessage = e.toString();
//           _isInitialized = false;
//         });
//       }
//     }
//   }

//   void _retryInitialization() {
//     setState(() {
//       _hasError = false;
//       _isInitialized = false;
//     });
//     _controller?.dispose();
//     _initializePlayer();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//         actions: [
//           if (_hasError)
//             IconButton(
//               icon: const Icon(Icons.refresh),
//               onPressed: _retryInitialization,
//             ),
//         ],
//       ),
//       backgroundColor: Colors.black,
//       body: Center(child: _buildBody()),
//     );
//   }

//   Widget _buildBody() {
//     if (_hasError) {
//       return Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.error_outline, color: Colors.red, size: 64),
//           const SizedBox(height: 16),
//           const Text(
//             'Failed to load video',
//             style: TextStyle(color: Colors.white, fontSize: 18),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Error: $_errorMessage',
//             style: const TextStyle(color: Colors.grey, fontSize: 14),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: _retryInitialization,
//             icon: const Icon(Icons.refresh),
//             label: const Text('Retry'),
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: () => _openInBrowser(),
//             icon: const Icon(Icons.open_in_browser),
//             label: const Text('Open in Browser'),
//           ),
//         ],
//       );
//     }

//     if (!_isInitialized) {
//       return const Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(color: Colors.white),
//           SizedBox(height: 16),
//           Text('Loading video...', style: TextStyle(color: Colors.white)),
//         ],
//       );
//     }

//     return AspectRatio(
//       aspectRatio: _controller!.value.aspectRatio,
//       child: Stack(
//         alignment: Alignment.bottomCenter,
//         children: [
//           VideoPlayer(_controller!),
//           _ControlsOverlay(controller: _controller!),
//           VideoProgressIndicator(_controller!, allowScrubbing: true),
//         ],
//       ),
//     );
//   }

//   void _openInBrowser() async {
//     // You can use url_launcher package for this
//     // For now, show a dialog with the URL
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Video URL'),
//         content: SelectableText(widget.videoUrl),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
// }

// class _ControlsOverlay extends StatelessWidget {
//   final VideoPlayerController controller;

//   const _ControlsOverlay({required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         controller.value.isPlaying ? controller.pause() : controller.play();
//       },
//       child: Stack(
//         children: <Widget>[
//           AnimatedSwitcher(
//             duration: const Duration(milliseconds: 50),
//             reverseDuration: const Duration(milliseconds: 200),
//             child: controller.value.isPlaying
//                 ? const SizedBox.shrink()
//                 : Container(
//                     color: Colors.black26,
//                     child: const Center(
//                       child: Icon(
//                         Icons.play_arrow,
//                         color: Colors.white,
//                         size: 100.0,
//                         semanticLabel: 'Play',
//                       ),
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:video_player/video_player.dart';

// class CoachPage extends StatefulWidget {
//   const CoachPage({super.key});

//   @override
//   State<CoachPage> createState() => _CoachPageState();
// }

// class _CoachPageState extends State<CoachPage> {
//   final supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> videos = [];
//   List<Map<String, dynamic>> profiles = [];
//   bool isLoading = true;
//   String? selectedUserId;
//   final TextEditingController _scoreController = TextEditingController();
//   Set<String> expandedCards = {}; // Track which cards are expanded

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     setState(() => isLoading = true);

//     try {
//       // Load videos from storage
//       final videoFiles = await supabase.storage.from('videos').list();

//       // Load user profiles
//       final profileData = await supabase
//           .from('profiles')
//           .select('*')
//           .order('created_at', ascending: false);

//       setState(() {
//         videos = videoFiles
//             .map(
//               (file) => {
//                 'name': file.name,
//                 'url': supabase.storage.from('videos').getPublicUrl(file.name),
//                 'updated_at': file.updatedAt,
//               },
//             )
//             .toList();

//         profiles = List<Map<String, dynamic>>.from(profileData);
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
//     }
//   }

//   Future<void> _updateScore(String userId, double score) async {
//     try {
//       await supabase.from('profiles').update({'score': score}).eq('id', userId);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Score updated successfully!')),
//       );

//       _loadData(); // Refresh data
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error updating score: $e')));
//     }
//   }

//   void _showScoreDialog(Map<String, dynamic> profile) {
//     _scoreController.text = profile['score']?.toString() ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Update Score for ${profile['full_name']}'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Current Score: ${profile['score'] ?? 'Not set'}'),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: _scoreController,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(
//                   labelText: 'New Score',
//                   border: OutlineInputBorder(),
//                   suffixText: 'pts',
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 final score = double.tryParse(_scoreController.text);
//                 if (score != null) {
//                   _updateScore(profile['id'], score);
//                   Navigator.of(context).pop();
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please enter a valid score')),
//                   );
//                 }
//               },
//               child: const Text('Update'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Coach Dashboard'),
//         backgroundColor: Theme.of(context).primaryColor,
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : DefaultTabController(
//               length: 2,
//               child: Column(
//                 children: [
//                   Container(
//                     color: Theme.of(context).primaryColor,
//                     child: const TabBar(
//                       indicatorColor: Colors.white,
//                       labelColor: Colors.white,
//                       unselectedLabelColor: Colors.white70,
//                       tabs: [
//                         Tab(icon: Icon(Icons.video_library), text: 'Videos'),
//                         Tab(icon: Icon(Icons.people), text: 'Athletes'),
//                       ],
//                     ),
//                   ),
//                   Expanded(
//                     child: TabBarView(
//                       children: [_buildVideosTab(), _buildAthletesTab()],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildVideosTab() {
//     return videos.isEmpty
//         ? const Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.video_library_outlined,
//                   size: 64,
//                   color: Colors.grey,
//                 ),
//                 SizedBox(height: 16),
//                 Text(
//                   'No videos found',
//                   style: TextStyle(fontSize: 18, color: Colors.grey),
//                 ),
//               ],
//             ),
//           )
//         : GridView.builder(
//             padding: const EdgeInsets.all(16),
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2,
//               childAspectRatio: 16 / 10,
//               crossAxisSpacing: 16,
//               mainAxisSpacing: 16,
//             ),
//             itemCount: videos.length,
//             itemBuilder: (context, index) {
//               final video = videos[index];
//               return _buildVideoCard(video);
//             },
//           );
//   }

//   Widget _buildVideoCard(Map<String, dynamic> video) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () => _showVideoOptions(video),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.grey[200],
//                   borderRadius: const BorderRadius.vertical(
//                     top: Radius.circular(12),
//                   ),
//                 ),
//                 child: const Icon(
//                   Icons.play_circle_filled,
//                   size: 48,
//                   color: Colors.blue,
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     video['name'],
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Tap to view options',
//                     style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAthletesTab() {
//     // Filter out coaches from the list
//     final athletes = profiles
//         .where(
//           (profile) => profile['role']?.toString().toLowerCase() != 'coach',
//         )
//         .toList();

//     return athletes.isEmpty
//         ? const Center(
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.people_outlined, size: 64, color: Colors.grey),
//                   SizedBox(height: 16),
//                   Text(
//                     'No athletes found',
//                     style: TextStyle(fontSize: 18, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             ),
//           )
//         : ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: athletes.length,
//             itemBuilder: (context, index) {
//               final profile = athletes[index];
//               return _buildAthleteCard(profile);
//             },
//           );
//   }

//   Widget _buildAthleteCard(Map<String, dynamic> profile) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             CircleAvatar(
//               radius: 30,
//               backgroundColor: Colors.blue.shade100,
//               child: Text(
//                 profile['full_name']
//                         ?.toString()
//                         .substring(0, 1)
//                         .toUpperCase() ??
//                     'A',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.blue.shade800,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     profile['full_name'] ?? 'Unknown',
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 2,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.grey[200],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       'ID: ${profile['id'] ?? 'N/A'}',
//                       style: TextStyle(
//                         color: Colors.grey[700],
//                         fontSize: 12,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Age: ${profile['age'] ?? 'N/A'} | Role: ${profile['role'] ?? 'N/A'}',
//                     style: TextStyle(color: Colors.grey[600], fontSize: 14),
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.fitness_center,
//                         size: 16,
//                         color: Colors.grey[600],
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         'Pushups: ${profile['pushups'] ?? 0} | Squats: ${profile['squats'] ?? 0}',
//                         style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _getScoreColor(profile['score']),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     'Score: ${profile['score']?.toString() ?? 'Not set'}',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ElevatedButton.icon(
//                   onPressed: () => _showScoreDialog(profile),
//                   icon: const Icon(Icons.edit, size: 16),
//                   label: const Text('Update'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showVideoPlayer(Map<String, dynamic> video) {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) =>
//             VideoPlayerScreen(videoUrl: video['url'], title: video['name']),
//       ),
//     );
//   }

//   Color _getScoreColor(dynamic score) {
//     if (score == null) return Colors.grey;
//     final scoreValue = double.tryParse(score.toString()) ?? 0;
//     if (scoreValue >= 80) return Colors.green;
//     if (scoreValue >= 60) return Colors.orange;
//     return Colors.red;
//   }

//   void _showVideoOptions(Map<String, dynamic> video) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (BuildContext context) {
//         return Container(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 video['name'],
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 20),
//               ListTile(
//                 leading: const Icon(Icons.play_arrow),
//                 title: const Text('Play in App'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _showVideoPlayer(video);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.link),
//                 title: const Text('Copy Video URL'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _copyToClipboard(video['url']);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.download),
//                 title: const Text('Download Video'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _downloadVideo(video);
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _copyToClipboard(String url) {
//     // You'll need to add clipboard package to pubspec.yaml
//     // Clipboard.setData(ClipboardData(text: url));
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Video URL copied to clipboard')),
//     );
//   }

//   void _downloadVideo(Map<String, dynamic> video) {
//     // Implement download functionality if needed
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Download started for ${video['name']}')),
//     );
//   }

//   @override
//   void dispose() {
//     _scoreController.dispose();
//     super.dispose();
//   }
// }

// class VideoPlayerScreen extends StatefulWidget {
//   final String videoUrl;
//   final String title;

//   const VideoPlayerScreen({
//     super.key,
//     required this.videoUrl,
//     required this.title,
//   });

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   VideoPlayerController? _controller;
//   bool _isInitialized = false;
//   bool _hasError = false;
//   String _errorMessage = '';

//   @override
//   void initState() {
//     super.initState();
//     _initializePlayer();
//   }

//   Future<void> _initializePlayer() async {
//     try {
//       // Add headers for better compatibility
//       _controller = VideoPlayerController.networkUrl(
//         Uri.parse(widget.videoUrl),
//         httpHeaders: {'User-Agent': 'Mozilla/5.0 (compatible)'},
//       );

//       await _controller!.initialize();

//       if (mounted) {
//         setState(() {
//           _isInitialized = true;
//           _hasError = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _hasError = true;
//           _errorMessage = e.toString();
//           _isInitialized = false;
//         });
//       }
//     }
//   }

//   void _retryInitialization() {
//     setState(() {
//       _hasError = false;
//       _isInitialized = false;
//     });
//     _controller?.dispose();
//     _initializePlayer();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//         actions: [
//           if (_hasError)
//             IconButton(
//               icon: const Icon(Icons.refresh),
//               onPressed: _retryInitialization,
//             ),
//         ],
//       ),
//       backgroundColor: Colors.black,
//       body: Center(child: _buildBody()),
//     );
//   }

//   Widget _buildBody() {
//     if (_hasError) {
//       return Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.error_outline, color: Colors.red, size: 64),
//           const SizedBox(height: 16),
//           const Text(
//             'Failed to load video',
//             style: TextStyle(color: Colors.white, fontSize: 18),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Error: $_errorMessage',
//             style: const TextStyle(color: Colors.grey, fontSize: 14),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: _retryInitialization,
//             icon: const Icon(Icons.refresh),
//             label: const Text('Retry'),
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: () => _openInBrowser(),
//             icon: const Icon(Icons.open_in_browser),
//             label: const Text('Open in Browser'),
//           ),
//         ],
//       );
//     }

//     if (!_isInitialized) {
//       return const Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(color: Colors.white),
//           SizedBox(height: 16),
//           Text('Loading video...', style: TextStyle(color: Colors.white)),
//         ],
//       );
//     }

//     return AspectRatio(
//       aspectRatio: _controller!.value.aspectRatio,
//       child: Stack(
//         alignment: Alignment.bottomCenter,
//         children: [
//           VideoPlayer(_controller!),
//           _ControlsOverlay(controller: _controller!),
//           VideoProgressIndicator(_controller!, allowScrubbing: true),
//         ],
//       ),
//     );
//   }

//   void _openInBrowser() async {
//     // You can use url_launcher package for this
//     // For now, show a dialog with the URL
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Video URL'),
//         content: SelectableText(widget.videoUrl),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
// }

// class _ControlsOverlay extends StatelessWidget {
//   final VideoPlayerController controller;

//   const _ControlsOverlay({required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         controller.value.isPlaying ? controller.pause() : controller.play();
//       },
//       child: Stack(
//         children: <Widget>[
//           AnimatedSwitcher(
//             duration: const Duration(milliseconds: 50),
//             reverseDuration: const Duration(milliseconds: 200),
//             child: controller.value.isPlaying
//                 ? const SizedBox.shrink()
//                 : Container(
//                     color: Colors.black26,
//                     child: const Center(
//                       child: Icon(
//                         Icons.play_arrow,
//                         color: Colors.white,
//                         size: 100.0,
//                         semanticLabel: 'Play',
//                       ),
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> videos = [];
  List<Map<String, dynamic>> profiles = [];
  bool isLoading = true;
  String? selectedUserId;
  final TextEditingController _scoreController = TextEditingController();
  Set<String> expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Load videos from storage
      final videoFiles = await supabase.storage.from('videos').list();

      // Load user profiles
      final profileData = await supabase
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        videos = videoFiles
            .map(
              (file) => {
                'name': file.name,
                'url': supabase.storage.from('videos').getPublicUrl(file.name),
                'updated_at': file.updatedAt,
              },
            )
            .toList();

        profiles = List<Map<String, dynamic>>.from(profileData);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _updateScore(String userId, double score) async {
    try {
      await supabase.from('profiles').update({'score': score}).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Score updated successfully!')),
        );
      }

      _loadData(); // Refresh data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating score: $e')));
      }
    }
  }

  void _showScoreDialog(Map<String, dynamic> profile) {
    _scoreController.text = profile['score']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Score for ${profile['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Score: ${profile['score'] ?? 'Not set'}'),
              const SizedBox(height: 16),
              TextField(
                controller: _scoreController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New Score',
                  border: OutlineInputBorder(),
                  suffixText: 'pts',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final score = double.tryParse(_scoreController.text);
                if (score != null) {
                  _updateScore(profile['id'], score);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid score')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Theme.of(context).primaryColor,
                    child: const TabBar(
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(icon: Icon(Icons.video_library), text: 'Videos'),
                        Tab(icon: Icon(Icons.people), text: 'Athletes'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_buildVideosTab(), _buildAthletesTab()],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVideosTab() {
    return videos.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No videos found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 16 / 10,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return _buildVideoCard(video);
            },
          );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVideoOptions(video),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.play_circle_filled,
                  size: 48,
                  color: Colors.blue,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view options',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAthletesTab() {
    final athletes = profiles
        .where(
          (profile) => profile['role']?.toString().toLowerCase() != 'coach',
        )
        .toList();

    return athletes.isEmpty
        ? const Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No athletes found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: athletes.length,
            itemBuilder: (context, index) {
              final profile = athletes[index];
              return _buildAthleteCard(profile);
            },
          );
  }

  Widget _buildAthleteCard(Map<String, dynamic> profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                profile['full_name']
                        ?.toString()
                        .substring(0, 1)
                        .toUpperCase() ??
                    'A',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile['full_name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ID: ${profile['id'] ?? 'N/A'}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${profile['age'] ?? 'N/A'} | Role: ${profile['role'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pushups: ${profile['pushups'] ?? 0} | Squats: ${profile['squats'] ?? 0}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(profile['score']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Score: ${profile['score']?.toString() ?? 'Not set'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showScoreDialog(profile),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(dynamic score) {
    if (score == null) return Colors.grey;
    final scoreValue = double.tryParse(score.toString()) ?? 0;
    if (scoreValue >= 80) return Colors.green;
    if (scoreValue >= 60) return Colors.orange;
    return Colors.red;
  }

  void _showVideoOptions(Map<String, dynamic> video) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                video['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                title: const Text('Play Video'),
                onTap: () {
                  Navigator.pop(context);
                  _playVideo(video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser, color: Colors.blue),
                title: const Text('Open in Browser'),
                onTap: () {
                  Navigator.pop(context);
                  _openInBrowser(video['url']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.orange),
                title: const Text('Copy URL'),
                onTap: () {
                  Navigator.pop(context);
                  _copyToClipboard(video['url']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _playVideo(Map<String, dynamic> video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImprovedVideoPlayerScreen(
          videoUrl: video['url'],
          title: video['name'],
        ),
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open URL in browser')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening URL: $e')));
      }
    }
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL copied to clipboard')));
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }
}

// Improved Video Player Screen
class ImprovedVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const ImprovedVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<ImprovedVideoPlayerScreen> createState() =>
      _ImprovedVideoPlayerScreenState();
}

class _ImprovedVideoPlayerScreenState extends State<ImprovedVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      debugPrint('🎥 Attempting to load video: ${widget.videoUrl}');

      // Dispose previous controller if exists
      await _controller?.dispose();

      // First, let's test if the URL is accessible
      await _testVideoUrl();

      // Create new controller with multiple fallback configurations
      await _tryInitializeWithDifferentConfigs();
    } catch (e) {
      debugPrint('❌ Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _getErrorMessage(e);
          _isLoading = false;
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _testVideoUrl() async {
    debugPrint('🔍 Testing video URL accessibility...');

    try {
      final uri = Uri.parse(widget.videoUrl);
      debugPrint('📍 Parsed URI: $uri');
      debugPrint('🌐 Host: ${uri.host}');
      debugPrint('📂 Path: ${uri.path}');

      // Check if it's a Supabase URL
      if (uri.host.contains('supabase')) {
        debugPrint('☁️ Detected Supabase storage URL');
      }
    } catch (e) {
      debugPrint('⚠️ URL parsing error: $e');
      throw Exception('Invalid video URL format');
    }
  }

  Future<void> _tryInitializeWithDifferentConfigs() async {
    // Configuration 1: Basic setup
    try {
      debugPrint('🔧 Trying basic configuration...');
      await _initWithConfig(1);
      return;
    } catch (e) {
      debugPrint('❌ Basic config failed: $e');
    }

    // Configuration 2: With specific headers
    try {
      debugPrint('🔧 Trying with headers...');
      await _initWithConfig(2);
      return;
    } catch (e) {
      debugPrint('❌ Headers config failed: $e');
    }

    // Configuration 3: Minimal setup
    try {
      debugPrint('🔧 Trying minimal configuration...');
      await _initWithConfig(3);
      return;
    } catch (e) {
      debugPrint('❌ Minimal config failed: $e');
      throw Exception('All initialization methods failed');
    }
  }

  Future<void> _initWithConfig(int configType) async {
    VideoPlayerController controller;

    switch (configType) {
      case 1:
        // Basic configuration
        controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: false,
          ),
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            'Accept': '*/*',
            'Range': 'bytes=0-',
          },
        );
        break;
      case 2:
        // With Supabase-specific headers
        controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          httpHeaders: {
            'User-Agent': 'FlutterApp/1.0',
            'Accept': 'video/mp4,video/*,*/*',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        );
        break;
      case 3:
      default:
        // Minimal configuration
        controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
        break;
    }

    // Set timeout for initialization
    _controller = controller;
    _controller!.addListener(_videoPlayerListener);

    // Add timeout to prevent infinite loading
    await _controller!.initialize().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Video initialization timeout after 30 seconds');
      },
    );

    debugPrint('✅ Video initialized successfully with config $configType');
    debugPrint('📐 Video size: ${_controller!.value.size}');
    debugPrint('⏱️ Video duration: ${_controller!.value.duration}');

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _hasError = false;
      });

      // Auto play the video
      debugPrint('▶️ Starting video playback...');
      await _controller!.play();
    }
  }

  void _videoPlayerListener() {
    if (mounted) {
      setState(() {});
    }
  }

  String _getErrorMessage(dynamic error) {
    String errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timeout')) {
      return 'Connection timeout after 30 seconds.\n\nThis usually indicates:\n• Supabase storage issues\n• Large video file\n• Network problems\n\nTry opening in browser instead.';
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return 'Network connection error.\n\nPossible causes:\n• Internet connection issues\n• Supabase server problems\n• CORS policy restrictions';
    } else if (errorStr.contains('format') || errorStr.contains('codec')) {
      return 'Video format not supported.\n\nSupported formats:\n• MP4 (recommended)\n• WebM\n• MOV';
    } else if (errorStr.contains('permission') ||
        errorStr.contains('access') ||
        errorStr.contains('403') ||
        errorStr.contains('401')) {
      return 'Access denied to video.\n\nPossible issues:\n• Supabase RLS (Row Level Security)\n• Private storage bucket\n• Expired access token';
    } else if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Video not found.\n\nCheck if:\n• Video file exists in Supabase storage\n• File path is correct\n• Bucket name is correct';
    } else {
      return 'Video loading failed.\n\nError details:\n${error.toString()}\n\nTry opening in browser for more info.';
    }
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    // Hide controls after 3 seconds
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller?.value.isPlaying == true) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_hasError)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initializeVideoPlayer,
              tooltip: 'Retry',
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _showUrlDialog(),
            tooltip: 'Open URL',
          ),
        ],
      ),
      body: Center(child: _buildVideoWidget()),
    );
  }

  Widget _buildVideoWidget() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Video Playback Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeVideoPlayer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openVideoInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open in Browser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _showUrlDialog,
                  icon: const Icon(Icons.link),
                  label: const Text('View URL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Text(
        'Video not initialized',
        style: TextStyle(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            if (_showControls) _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Container(
      color: Colors.black26,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top controls (can add more controls here)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          // Center play button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
          // Bottom progress bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: const VideoProgressColors(
                    playedColor: Colors.red,
                    bufferedColor: Colors.grey,
                    backgroundColor: Colors.white24,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideoInBrowser() async {
    final uri = Uri.parse(widget.videoUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showUrlDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _showUrlDialog();
      }
    }
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Full URL:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                widget.videoUrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Troubleshooting:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Try opening this URL in your browser\n'
              '• Check if video loads in browser\n'
              '• Verify Supabase storage settings\n'
              '• Check file permissions',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.videoUrl));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied to clipboard')),
              );
            },
            child: const Text('Copy URL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoPlayerListener);
    _controller?.dispose();
    super.dispose();
  }
}

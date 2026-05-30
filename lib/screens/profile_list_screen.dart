import 'package:flutter/material.dart';
import '../services/profile_storage_service.dart';
import '../models/user_profile.dart';
import 'profile_screen.dart';

class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({super.key});

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  final ProfileStorageService _profileStorage = ProfileStorageService();
  Map<String, UserProfile> _profiles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    _profiles = await _profileStorage.loadAllProfiles();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profiles'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No user profiles found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Login with Facebook to create a profile',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles.values.elementAt(index);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profile.profilePictureUrl != null
                              ? NetworkImage(profile.profilePictureUrl!)
                              : null,
                          child: profile.profilePictureUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          profile.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${profile.totalCommentsAnalyzed} comments • ${profile.personScores.length} people',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: profile.userId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
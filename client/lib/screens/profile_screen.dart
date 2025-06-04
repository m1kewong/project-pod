import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    if (!authService.isAuthenticated) {
      return _buildUnauthenticatedView(context);
    }
    
    final user = authService.currentUser!;
    final isAnonymous = user.isAnonymous;
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Implement refresh functionality
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? Text(
                            _getInitials(user.displayName ?? 'User'),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Username & Display Name
                  Text(
                    user.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isAnonymous ? 'Guest User' : user.email ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat('Videos', '0'),
                      _buildStat('Followers', '0'),
                      _buildStat('Following', '0'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Edit Profile Button
                  if (!isAnonymous)
                    OutlinedButton(
                      onPressed: () {
                        // TODO: Implement edit profile
                      },
                      child: const Text('Edit Profile'),
                    ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Account Settings
            _buildSettingsSection(context, 'Account Settings', [
              _buildSettingsTile(
                context,
                'Personal Information',
                Icons.person,
                () {
                  // TODO: Navigate to personal info screen
                },
              ),
              _buildSettingsTile(
                context,
                'Privacy',
                Icons.privacy_tip,
                () {
                  // TODO: Navigate to privacy settings
                },
              ),
              _buildSettingsTile(
                context,
                'Notifications',
                Icons.notifications,
                () {
                  // TODO: Navigate to notification settings
                },
              ),
            ]),
            
            // App Settings
            _buildSettingsSection(context, 'App Settings', [
              _buildSettingsTile(
                context,
                'Dark Mode',
                Icons.dark_mode,
                () {
                  // TODO: Toggle dark mode
                },
              ),
              _buildSettingsTile(
                context,
                'Language',
                Icons.language,
                () {
                  // TODO: Navigate to language settings
                },
              ),
              _buildSettingsTile(
                context,
                'Help & Support',
                Icons.help,
                () {
                  // TODO: Navigate to help & support
                },
              ),
            ]),
            
            // Sign Out Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () async {
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUnauthenticatedView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          const Text(
            'Sign in to view your profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStat(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label),
      ],
    );
  }
  
  Widget _buildSettingsSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
  
  Widget _buildSettingsTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
  
  String _getInitials(String name) {
    if (name.isEmpty) return '';
    
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    } else {
      return name[0];
    }
  }
}

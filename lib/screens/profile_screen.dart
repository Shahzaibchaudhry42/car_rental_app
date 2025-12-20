import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../models/user_model.dart';
import '../models/booking_model.dart';
import 'login_screen.dart';
import 'my_bookings_screen.dart';

/// Profile screen for user account management
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final BookingService _bookingService = BookingService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data
  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _user = null;
          _isLoading = false;
        });
        return;
      }

      UserModel? userData;
      try {
        userData = await _authService.getUserData(currentUser.uid);
      } catch (e) {
        final message = e.toString();
        // If Firestore rules block reads, fall back to auth profile data.
        if (message.contains('permission-denied') ||
            message.contains('PERMISSION_DENIED')) {
          userData = UserModel(
            uid: currentUser.uid,
            email: currentUser.email ?? '',
            name: (currentUser.displayName ?? '').trim().isNotEmpty
                ? currentUser.displayName!.trim()
                : 'User',
            phoneNumber: currentUser.phoneNumber,
            photoUrl: currentUser.photoURL,
            createdAt: DateTime.now(),
          );
        } else {
          rethrow;
        }
      }

      // If the user doc doesn't exist (common before seeding), use auth data.
      userData ??= UserModel(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        name: (currentUser.displayName ?? '').trim().isNotEmpty
            ? currentUser.displayName!.trim()
            : 'User',
        phoneNumber: currentUser.phoneNumber,
        photoUrl: currentUser.photoURL,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _user = userData;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Sign out
  Future<void> _signOut() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Edit profile
  Future<void> _editProfile() async {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user!.name);
    final phoneController = TextEditingController(text: _user!.phoneNumber);

    bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      try {
        await _authService.updateUserProfile(
          uid: _user!.uid,
          name: nameController.text.trim(),
          phoneNumber: phoneController.text.trim(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _loadUserData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    nameController.dispose();
    phoneController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_rounded, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'You are not signed in',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Please login to view your profile.',
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Theme.of(context).primaryColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Profile Avatar with Animation
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 56,
                                  backgroundImage: _user!.photoUrl != null
                                      ? NetworkImage(_user!.photoUrl!)
                                      : null,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.2),
                                  child: _user!.photoUrl == null
                                      ? Text(
                                          _user!.name[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _user!.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _user!.email,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                      if (_user!.phoneNumber != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _user!.phoneNumber!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      if (_user!.isAdmin) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: _editProfile,
                ),
              ),
            ],
          ),
          // Menu Items
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Account overview statistics
                _buildAccountOverviewSection(),
                const SizedBox(height: 16),
                _buildModernMenuItem(
                  icon: Icons.history_rounded,
                  title: 'My Bookings',
                  subtitle: 'View your booking history',
                  gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyBookingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildModernMenuItem(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  subtitle: 'Manage your notifications',
                  gradient: [const Color(0xFF10B981), const Color(0xFF14B8A6)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feature coming soon!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildModernMenuItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'App preferences and settings',
                  gradient: [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feature coming soon!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildModernMenuItem(
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get help and support',
                  gradient: [const Color(0xFFF59E0B), const Color(0xFFF97316)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feature coming soon!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildModernMenuItem(
                  icon: Icons.info_rounded,
                  title: 'About',
                  subtitle: 'App information',
                  gradient: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Car Rental App',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(
                        Icons.directions_car_rounded,
                        size: 48,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Sign Out Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _signOut,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Build account overview with booking statistics
  Widget _buildAccountOverviewSection() {
    return StreamBuilder<List<BookingModel>>(
      stream: _bookingService.getUserBookingsStream(_user!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final message = snapshot.error.toString();
          final isPermissionDenied =
              message.contains('permission-denied') ||
              message.contains('PERMISSION_DENIED');

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPermissionDenied
                        ? 'Booking stats are unavailable due to Firestore permissions.'
                        : 'Unable to load booking stats right now.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No bookings yet. Start your first ride today!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }

        final bookings = snapshot.data!;
        final now = DateTime.now();

        int total = bookings.length;
        int active = bookings
            .where(
              (b) =>
                  b.status == BookingStatus.pending ||
                  b.status == BookingStatus.approved,
            )
            .length;
        int completed = bookings
            .where((b) => b.status == BookingStatus.completed)
            .length;
        double totalSpent = bookings
            .where((b) => b.isPaid)
            .fold(0.0, (sum, b) => sum + b.totalPrice);
        int upcoming = bookings
            .where(
              (b) =>
                  (b.status == BookingStatus.approved ||
                      b.status == BookingStatus.pending) &&
                  b.startDate.isAfter(now),
            )
            .length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  _buildOverviewStatCard(
                    label: 'Total Bookings',
                    value: total.toString(),
                    icon: Icons.list_alt_rounded,
                    color: const Color(0xFF6366F1),
                  ),
                  _buildOverviewStatCard(
                    label: 'Active',
                    value: active.toString(),
                    icon: Icons.timelapse_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                  _buildOverviewStatCard(
                    label: 'Upcoming',
                    value: upcoming.toString(),
                    icon: Icons.calendar_today_rounded,
                    color: const Color(0xFF10B981),
                  ),
                  _buildOverviewStatCard(
                    label: 'Total Spent',
                    value: '₹${totalSpent.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build modern menu item
  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

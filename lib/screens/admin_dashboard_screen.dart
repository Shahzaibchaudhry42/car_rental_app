import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../services/car_service.dart';
import 'admin_cars_screen.dart';
import 'admin_bookings_screen.dart';

/// Admin dashboard screen
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final CarService _carService = CarService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _loadStatistics();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Load booking statistics
  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> stats = await _bookingService.getBookingStatistics();
      setState(() {
        _statistics = stats;
      });
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading statistics: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
              Theme.of(context).primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 120,
                        floating: false,
                        pinned: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          title: const Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          background: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.3),
                                  Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (_statistics != null) ...[
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Overview',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildAnimatedStatsGrid(),
                                      const SizedBox(height: 32),
                                      const Text(
                                        'Quick Actions',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildAnimatedActionCards(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStatsGrid() {
    final stats = [
      {
        'title': 'Total Bookings',
        'value': _statistics!['totalBookings'].toString(),
        'icon': Icons.book_rounded,
        'color': const Color(0xFF6366F1),
        'delay': 0,
      },
      {
        'title': 'Pending',
        'value': _statistics!['pendingBookings'].toString(),
        'icon': Icons.pending_rounded,
        'color': const Color(0xFFF59E0B),
        'delay': 100,
      },
      {
        'title': 'Approved',
        'value': _statistics!['approvedBookings'].toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
        'delay': 200,
      },
      {
        'title': 'Completed',
        'value': _statistics!['completedBookings'].toString(),
        'icon': Icons.done_all_rounded,
        'color': const Color(0xFF14B8A6),
        'delay': 300,
      },
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final delay = stats[index]['delay'] as int;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + delay),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: _buildModernStatCard(
                    title: stats[index]['title'] as String,
                    value: stats[index]['value'] as String,
                    icon: stats[index]['icon'] as IconData,
                    color: stats[index]['color'] as Color,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1000),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: _buildRevenueCard());
          },
        ),
      ],
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Revenue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${_statistics!['totalRevenue'].toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedActionCards() {
    final actions = [
      {
        'title': 'Manage Cars',
        'subtitle': 'Add, edit, or remove cars',
        'icon': Icons.directions_car_rounded,
        'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminCarsScreen()),
          );
        },
        'delay': 0,
      },
      {
        'title': 'Manage Bookings',
        'subtitle': 'Approve or reject bookings',
        'icon': Icons.book_online_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF14B8A6)],
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminBookingsScreen(),
            ),
          );
        },
        'delay': 150,
      },
      {
        'title': 'View Reports',
        'subtitle': 'Analytics and insights',
        'icon': Icons.bar_chart_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFF97316)],
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reports feature coming soon!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        'delay': 300,
      },
    ];

    return Column(
      children: actions.map((action) {
        final delay = action['delay'] as int;
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + delay),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildModernActionCard(
                    title: action['title'] as String,
                    subtitle: action['subtitle'] as String,
                    icon: action['icon'] as IconData,
                    gradient: action['gradient'] as List<Color>,
                    onTap: action['onTap'] as VoidCallback,
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  /// Build statistics card
  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build action card
  Widget _buildModernActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

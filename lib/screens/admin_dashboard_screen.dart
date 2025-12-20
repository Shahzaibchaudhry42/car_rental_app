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

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final BookingService _bookingService = BookingService();
  final CarService _carService = CarService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// Load booking statistics
  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> stats = await _bookingService.getBookingStatistics();
      setState(() {
        _statistics = stats;
      });
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
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Statistics cards
                  if (_statistics != null) ...[
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Bookings',
                            value: _statistics!['totalBookings'].toString(),
                            icon: Icons.book,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Pending',
                            value: _statistics!['pendingBookings'].toString(),
                            icon: Icons.pending,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Approved',
                            value: _statistics!['approvedBookings'].toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Completed',
                            value: _statistics!['completedBookings'].toString(),
                            icon: Icons.done_all,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      title: 'Total Revenue',
                      value:
                          '₹${_statistics!['totalRevenue'].toStringAsFixed(0)}',
                      icon: Icons.attach_money,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Quick actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildActionCard(
                    title: 'Manage Cars',
                    subtitle: 'Add, edit, or remove cars',
                    icon: Icons.directions_car,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminCarsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    title: 'Manage Bookings',
                    subtitle: 'Approve or reject bookings',
                    icon: Icons.book,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminBookingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    title: 'View Reports',
                    subtitle: 'Analytics and insights',
                    icon: Icons.bar_chart,
                    color: Colors.orange,
                    onTap: () {
                      // Navigate to reports screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reports feature coming soon!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  /// Build statistics card
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  /// Build action card
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

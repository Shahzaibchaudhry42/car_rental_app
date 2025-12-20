import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';
import '../services/car_service.dart';
import '../services/auth_service.dart';
import '../models/car_model.dart';
import '../models/user_model.dart';
import 'car_detail_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';

/// Home screen displaying car listings
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CarService _carService = CarService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  final List<String> _categories = ['All'];
  List<CarModel> _searchResults = [];
  bool _isSearching = false;
  // Controls toggle behavior for the "All" filter chip
  bool _allFilterActive = true;
  bool _animate = false;
  UserModel? _currentUser;

  // Local sample cars used only in debug mode so that the
  // home screen always shows multiple cars without depending
  // on Firestore data or seed operations.
  final List<CarModel> _debugCars = [
    CarModel(
      id: 'bmw_3',
      name: 'BMW 3 Series',
      brand: 'BMW',
      model: '320i',
      year: 2023,
      category: 'Luxury',
      pricePerDay: 120.0,
      imageUrl: 'assets/images/bmw_3series.jpg',
      features: ['AC', 'GPS', 'Automatic', 'Leather Seats'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'Downtown Showroom',
      rating: 4.8,
      totalReviews: 210,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'merc_c',
      name: 'Mercedes C-Class',
      brand: 'Mercedes-Benz',
      model: 'C 200',
      year: 2023,
      category: 'Luxury',
      pricePerDay: 135.0,
      imageUrl: 'assets/images/mercedes_cclass.jpg',
      features: ['AC', 'Bluetooth', 'Sunroof', 'Automatic'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'City Center',
      rating: 4.9,
      totalReviews: 160,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'audi_a4',
      name: 'Audi A4',
      brand: 'Audi',
      model: 'A4',
      year: 2022,
      category: 'Sedan',
      pricePerDay: 110.0,
      imageUrl: 'assets/images/audi_a4.jpg',
      features: ['AC', 'GPS', 'Premium Sound'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'Downtown',
      rating: 4.7,
      totalReviews: 140,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'tesla_3',
      name: 'Tesla Model 3',
      brand: 'Tesla',
      model: 'Model 3',
      year: 2024,
      category: 'Electric',
      pricePerDay: 140.0,
      imageUrl: 'assets/images/tesla_model3.jpg',
      features: ['Autopilot', 'AC', 'GPS'],
      seatingCapacity: 5,
      fuelType: 'Electric',
      transmission: 'Automatic',
      location: 'Downtown',
      rating: 4.9,
      totalReviews: 200,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'toyota_corolla',
      name: 'Toyota Corolla',
      brand: 'Toyota',
      model: 'Corolla',
      year: 2022,
      category: 'Sedan',
      pricePerDay: 45.0,
      imageUrl: 'assets/images/toyota_corolla.jpg',
      features: ['AC', 'GPS', 'Automatic'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'Downtown',
      rating: 4.5,
      totalReviews: 180,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'honda_civic',
      name: 'Honda Civic',
      brand: 'Honda',
      model: 'Civic',
      year: 2023,
      category: 'Sedan',
      pricePerDay: 50.0,
      imageUrl: 'assets/images/honda_civic.jpg',
      features: ['AC', 'Bluetooth', 'Automatic'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'City Center',
      rating: 4.6,
      totalReviews: 150,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'suzuki_swift',
      name: 'Suzuki Swift',
      brand: 'Suzuki',
      model: 'Swift',
      year: 2022,
      category: 'Hatchback',
      pricePerDay: 35.0,
      imageUrl: 'assets/images/suzuki_swift.jpg',
      features: ['AC', 'Manual', 'Compact'],
      seatingCapacity: 4,
      fuelType: 'Petrol',
      transmission: 'Manual',
      location: 'Airport',
      rating: 4.3,
      totalReviews: 95,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'bmw_5',
      name: 'BMW 5 Series',
      brand: 'BMW',
      model: '530i',
      year: 2023,
      category: 'Luxury',
      pricePerDay: 180.0,
      imageUrl: 'assets/images/bmw_5series.jpg',
      features: ['AC', 'GPS', 'Automatic', 'Premium Sound'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'Luxury Fleet',
      rating: 4.9,
      totalReviews: 120,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
    CarModel(
      id: 'audi_a6',
      name: 'Audi A6',
      brand: 'Audi',
      model: 'A6',
      year: 2023,
      category: 'Luxury',
      pricePerDay: 160.0,
      imageUrl: 'assets/images/audi_a6.jpg',
      features: ['AC', 'GPS', 'Sunroof', 'Automatic'],
      seatingCapacity: 5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      location: 'Downtown Showroom',
      rating: 4.8,
      totalReviews: 110,
      createdAt: DateTime.now(),
      updatedAt: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Animate content in after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animate = true);
      }
    });

    // Load current user data (for admin icon, etc.)
    _loadUserData();
  }

  /// Seed sample car documents into Firestore (debug only)
  Future<void> _seedSampleCars() async {
    if (!kDebugMode) return;
    try {
      final uuid = Uuid();
      final now = DateTime.now();
      final samples = [
        {
          'name': 'BMW 3 Series',
          'brand': 'BMW',
          'model': '320i',
          'year': 2023,
          'category': 'Luxury',
          'pricePerDay': 120.0,
          'imageUrl': 'assets/images/bmw_3series.jpg',
          'features': ['AC', 'GPS', 'Automatic', 'Leather Seats'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'Downtown Showroom',
          'rating': 4.8,
          'totalReviews': 210,
          'createdAt': now,
        },
        {
          'name': 'Mercedes C-Class',
          'brand': 'Mercedes-Benz',
          'model': 'C 200',
          'year': 2023,
          'category': 'Luxury',
          'pricePerDay': 135.0,
          'imageUrl': 'assets/images/mercedes_cclass.jpg',
          'features': ['AC', 'Bluetooth', 'Sunroof', 'Automatic'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'City Center',
          'rating': 4.9,
          'totalReviews': 160,
          'createdAt': now,
        },
        {
          'name': 'Audi A4',
          'brand': 'Audi',
          'model': 'A4',
          'year': 2022,
          'category': 'Sedan',
          'pricePerDay': 110.0,
          'imageUrl': 'assets/images/audi_a4.jpg',
          'features': ['AC', 'GPS', 'Premium Sound'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'Downtown',
          'rating': 4.7,
          'totalReviews': 140,
          'createdAt': now,
        },
        {
          'name': 'Tesla Model 3',
          'brand': 'Tesla',
          'model': 'Model 3',
          'year': 2024,
          'category': 'Electric',
          'pricePerDay': 140.0,
          'imageUrl': 'assets/images/tesla_model3.jpg',
          'features': ['Autopilot', 'AC', 'GPS'],
          'seatingCapacity': 5,
          'fuelType': 'Electric',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'Downtown',
          'rating': 4.9,
          'totalReviews': 200,
          'createdAt': now,
        },
        {
          'name': 'Toyota Corolla',
          'brand': 'Toyota',
          'model': 'Corolla',
          'year': 2022,
          'category': 'Sedan',
          'pricePerDay': 45.0,
          'imageUrl': 'assets/images/toyota_corolla.jpg',
          'features': ['AC', 'GPS', 'Automatic'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'Downtown',
          'rating': 4.5,
          'totalReviews': 180,
          'createdAt': now,
        },
        {
          'name': 'Honda Civic',
          'brand': 'Honda',
          'model': 'Civic',
          'year': 2023,
          'category': 'Sedan',
          'pricePerDay': 50.0,
          'imageUrl': 'assets/images/honda_civic.jpg',
          'features': ['AC', 'Bluetooth', 'Automatic'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'City Center',
          'rating': 4.6,
          'totalReviews': 150,
          'createdAt': now,
        },
        {
          'name': 'Suzuki Swift',
          'brand': 'Suzuki',
          'model': 'Swift',
          'year': 2022,
          'category': 'Hatchback',
          'pricePerDay': 35.0,
          'imageUrl': 'assets/images/suzuki_swift.jpg',
          'features': ['AC', 'Manual', 'Compact'],
          'seatingCapacity': 4,
          'fuelType': 'Petrol',
          'transmission': 'Manual',
          'isAvailable': true,
          'location': 'Airport',
          'rating': 4.3,
          'totalReviews': 95,
          'createdAt': now,
        },
        {
          'name': 'BMW 5 Series',
          'brand': 'BMW',
          'model': '530i',
          'year': 2023,
          'category': 'Luxury',
          'pricePerDay': 180.0,
          'imageUrl': 'assets/images/bmw_5series.jpg',
          'features': ['AC', 'GPS', 'Automatic', 'Premium Sound'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'Luxury Fleet',
          'rating': 4.9,
          'totalReviews': 120,
          'createdAt': now,
        },
        {
          'name': 'Audi A6',
          'brand': 'Audi',
          'model': 'A6',
          'year': 2023,
          'category': 'Luxury',
          'pricePerDay': 160.0,
          'imageUrl': 'assets/images/audi_a6.jpg',
          'features': ['AC', 'GPS', 'Sunroof', 'Automatic'],
          'seatingCapacity': 5,
          'fuelType': 'Petrol',
          'transmission': 'Automatic',
          'isAvailable': true,
          'location': 'Downtown Showroom',
          'rating': 4.8,
          'totalReviews': 110,
          'createdAt': now,
        },
      ];

      for (var s in samples) {
        await _carService.addCar(
          CarModel(
            id: uuid.v4(),
            name: s['name'] as String,
            brand: s['brand'] as String,
            model: s['model'] as String,
            year: s['year'] as int,
            category: s['category'] as String,
            pricePerDay: (s['pricePerDay'] as num).toDouble(),
            imageUrl: s['imageUrl'] as String,
            features: List<String>.from(s['features'] as List),
            seatingCapacity: s['seatingCapacity'] as int,
            fuelType: s['fuelType'] as String,
            transmission: s['transmission'] as String,
            isAvailable: s['isAvailable'] as bool,
            location: s['location'] as String,
            rating: (s['rating'] as num).toDouble(),
            totalReviews: s['totalReviews'] as int,
            createdAt: s['createdAt'] as DateTime,
            updatedAt: null,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample cars added to Firestore')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add sample cars: $e')),
        );
      }
    }
  }

  /// Load current user data
  Future<void> _loadUserData() async {
    User? user = _authService.currentUser;
    if (user != null) {
      UserModel? userData = await _authService.getUserData(user.uid);
      setState(() {
        _currentUser = userData;
      });
    }
  }

  /// Search cars
  Future<void> _searchCars(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    // In debug mode, search local sample cars so it works
    // even if Firestore has no data or restricted rules.
    if (kDebugMode) {
      final lower = query.toLowerCase();
      final results = _debugCars.where((car) {
        return car.name.toLowerCase().contains(lower) ||
            car.brand.toLowerCase().contains(lower) ||
            car.model.toLowerCase().contains(lower);
      }).toList();

      setState(() {
        _searchResults = results;
      });
      return;
    }

    try {
      List<CarModel> results = await _carService.searchCars(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      final message = e.toString();

      // If Firestore blocks reads (permission-denied / offline),
      // just show no results instead of an error Snackbar.
      if (message.contains('permission-denied') ||
          message.contains('unavailable')) {
        if (mounted) {
          setState(() {
            _searchResults = [];
          });
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[900]!, Colors.blue[700]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            offset: _animate ? Offset.zero : const Offset(0, 0.05),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _animate ? 1 : 0,
              child: Column(
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[900]!, Colors.blue[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Car Rental',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                if (_currentUser?.isAdmin == true)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AdminDashboardScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ProfileScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Search for your dream car...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.blue[700],
                                size: 24,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchCars('');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            onChanged: _searchCars,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Category Chips
                  Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          String category = _categories[index];

                          // 'All' behaves as a toggle: tap once to show, again to hide
                          bool isSelected = category == 'All'
                              ? _allFilterActive
                              : _selectedCategory == category;

                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FilterChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.blue[700],
                              backgroundColor: Colors.white,
                              elevation: isSelected ? 4 : 0,
                              shadowColor: Colors.blue[700],
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.blue[700]!
                                    : Colors.grey[300]!,
                                width: 1.5,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (category == 'All') {
                                    // Toggle the All filter on/off
                                    _allFilterActive = !_allFilterActive;
                                    _selectedCategory = 'All';
                                  } else {
                                    // Selecting any other category keeps it selected
                                    _allFilterActive = true;
                                    _selectedCategory = category;
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isSearching
                        // When searching, always show only search results
                        ? _buildCarList(_searchResults)
                        : (!_allFilterActive && _selectedCategory == 'All')
                        // 'All' toggled off: intentionally show no cars
                        ? _buildCarList(const [])
                        : kDebugMode
                        // In debug mode show local sample cars
                        ? _buildCarList(_debugCars)
                        : StreamBuilder<List<CarModel>>(
                            stream: _selectedCategory == 'All'
                                ? _carService.getCarsStream()
                                : _carService.getCarsByCategory(
                                    _selectedCategory,
                                  ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No cars available',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              return _buildCarList(snapshot.data!);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build car list widget
  Widget _buildCarList(List<CarModel> cars) {
    return Container(
      color: Colors.grey[50],
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          // Higher aspect ratio -> visually shorter cards
          childAspectRatio: 0.95,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: cars.length,
        itemBuilder: (context, index) {
          CarModel car = cars[index];
          return _buildCarCard(car);
        },
      ),
    );
  }

  /// Build car card widget
  Widget _buildCarCard(CarModel car) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CarDetailScreen(car: car)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: Image.asset(
                      car.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.directions_car,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Rating Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${car.rating}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Car Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${car.brand} • ${car.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        // Features Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildDetailIcon(
                              Icons.airline_seat_recline_normal,
                              '${car.seatingCapacity}',
                            ),
                            const SizedBox(width: 12),
                            _buildDetailIcon(
                              Icons.settings,
                              car.transmission[0].toUpperCase(),
                            ),
                            const SizedBox(width: 12),
                            _buildDetailIcon(
                              Icons.local_gas_station,
                              car.fuelType[0].toUpperCase(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Price Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${car.pricePerDay.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  '/day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail icon widget
  Widget _buildDetailIcon(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

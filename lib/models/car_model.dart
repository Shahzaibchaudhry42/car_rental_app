import 'package:cloud_firestore/cloud_firestore.dart';

/// Car model representing vehicles available for rent
class CarModel {
  final String id;
  final String name;
  final String brand;
  final String model;
  final int year;
  final String category; // SUV, Sedan, Hatchback, Luxury, etc.
  final double pricePerDay;
  final String imageUrl;
  final List<String> features; // AC, GPS, etc.
  final int seatingCapacity;
  final String fuelType; // Petrol, Diesel, Electric, Hybrid
  final String transmission; // Manual, Automatic
  final bool isAvailable;
  final String location;
  final double rating;
  final int totalReviews;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CarModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.year,
    required this.category,
    required this.pricePerDay,
    required this.imageUrl,
    required this.features,
    required this.seatingCapacity,
    required this.fuelType,
    required this.transmission,
    this.isAvailable = true,
    required this.location,
    this.rating = 0.0,
    this.totalReviews = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create CarModel from Firestore document
  factory CarModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CarModel(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 2024,
      category: data['category'] ?? '',
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      features: List<String>.from(data['features'] ?? []),
      seatingCapacity: data['seatingCapacity'] ?? 4,
      fuelType: data['fuelType'] ?? 'Petrol',
      transmission: data['transmission'] ?? 'Manual',
      isAvailable: data['isAvailable'] ?? true,
      location: data['location'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert CarModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'year': year,
      'category': category,
      'pricePerDay': pricePerDay,
      'imageUrl': imageUrl,
      'features': features,
      'seatingCapacity': seatingCapacity,
      'fuelType': fuelType,
      'transmission': transmission,
      'isAvailable': isAvailable,
      'location': location,
      'rating': rating,
      'totalReviews': totalReviews,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create a copy of CarModel with updated fields
  CarModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? model,
    int? year,
    String? category,
    double? pricePerDay,
    String? imageUrl,
    List<String>? features,
    int? seatingCapacity,
    String? fuelType,
    String? transmission,
    bool? isAvailable,
    String? location,
    double? rating,
    int? totalReviews,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CarModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      category: category ?? this.category,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      imageUrl: imageUrl ?? this.imageUrl,
      features: features ?? this.features,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      isAvailable: isAvailable ?? this.isAvailable,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

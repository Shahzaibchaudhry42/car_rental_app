import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/car_model.dart';

/// Service for handling car-related operations
class CarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get all cars stream
  Stream<List<CarModel>> getCarsStream() {
    return _firestore
        .collection('cars')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CarModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get available cars stream
  Stream<List<CarModel>> getAvailableCarsStream() {
    return _firestore
        .collection('cars')
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CarModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get cars by category
  Stream<List<CarModel>> getCarsByCategory(String category) {
    return _firestore
        .collection('cars')
        .where('category', isEqualTo: category)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => CarModel.fromFirestore(doc)).toList(),
        );
  }

  /// Get car by ID
  Future<CarModel?> getCarById(String carId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('cars')
          .doc(carId)
          .get();
      if (doc.exists) {
        return CarModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to get car: $e';
    }
  }

  /// Search cars by name or brand
  Future<List<CarModel>> searchCars(String query) async {
    try {
      // Convert query to lowercase for case-insensitive search
      String lowerQuery = query.toLowerCase();

      // Get all cars and filter in memory (Firestore doesn't support full-text search)
      QuerySnapshot snapshot = await _firestore.collection('cars').get();

      List<CarModel> cars = snapshot.docs
          .map((doc) => CarModel.fromFirestore(doc))
          .where(
            (car) =>
                car.name.toLowerCase().contains(lowerQuery) ||
                car.brand.toLowerCase().contains(lowerQuery) ||
                car.model.toLowerCase().contains(lowerQuery),
          )
          .toList();

      return cars;
    } catch (e) {
      throw 'Failed to search cars: $e';
    }
  }

  /// Filter cars by multiple criteria
  Future<List<CarModel>> filterCars({
    String? category,
    double? maxPrice,
    double? minPrice,
    String? fuelType,
    String? transmission,
    int? minSeating,
    String? location,
  }) async {
    try {
      Query query = _firestore.collection('cars');

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      if (fuelType != null) {
        query = query.where('fuelType', isEqualTo: fuelType);
      }
      if (transmission != null) {
        query = query.where('transmission', isEqualTo: transmission);
      }
      if (location != null) {
        query = query.where('location', isEqualTo: location);
      }

      QuerySnapshot snapshot = await query.get();
      List<CarModel> cars = snapshot.docs
          .map((doc) => CarModel.fromFirestore(doc))
          .toList();

      // Apply additional filters in memory
      if (maxPrice != null) {
        cars = cars.where((car) => car.pricePerDay <= maxPrice).toList();
      }
      if (minPrice != null) {
        cars = cars.where((car) => car.pricePerDay >= minPrice).toList();
      }
      if (minSeating != null) {
        cars = cars.where((car) => car.seatingCapacity >= minSeating).toList();
      }

      return cars;
    } catch (e) {
      throw 'Failed to filter cars: $e';
    }
  }

  /// Add a new car (Admin only)
  Future<String> addCar(CarModel car) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('cars')
          .add(car.toMap());
      return docRef.id;
    } catch (e) {
      throw 'Failed to add car: $e';
    }
  }

  /// Update car details (Admin only)
  Future<void> updateCar(String carId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection('cars').doc(carId).update(updates);
    } catch (e) {
      throw 'Failed to update car: $e';
    }
  }

  /// Delete car (Admin only)
  Future<void> deleteCar(String carId) async {
    try {
      await _firestore.collection('cars').doc(carId).delete();
    } catch (e) {
      throw 'Failed to delete car: $e';
    }
  }

  /// Upload car image to Firebase Storage
  Future<String> uploadCarImage(File imageFile, String carId) async {
    try {
      String fileName =
          'cars/$carId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload image: $e';
    }
  }

  /// Check if car is available for specific dates
  Future<bool> checkCarAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Get car details
      CarModel? car = await getCarById(carId);
      if (car == null || !car.isAvailable) {
        return false;
      }

      // Check for overlapping bookings
      QuerySnapshot bookings = await _firestore
          .collection('bookings')
          .where('carId', isEqualTo: carId)
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      for (var doc in bookings.docs) {
        DateTime bookingStart =
            (doc.data() as Map<String, dynamic>)['startDate'].toDate();
        DateTime bookingEnd = (doc.data() as Map<String, dynamic>)['endDate']
            .toDate();

        // Check for date overlap
        if ((startDate.isBefore(bookingEnd) ||
                startDate.isAtSameMomentAs(bookingEnd)) &&
            (endDate.isAfter(bookingStart) ||
                endDate.isAtSameMomentAs(bookingStart))) {
          return false; // Car is already booked for these dates
        }
      }

      return true; // Car is available
    } catch (e) {
      throw 'Failed to check availability: $e';
    }
  }

  /// Update car availability status
  Future<void> updateCarAvailability(String carId, bool isAvailable) async {
    try {
      await _firestore.collection('cars').doc(carId).update({
        'isAvailable': isAvailable,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Failed to update availability: $e';
    }
  }

  /// Get car categories
  Future<List<String>> getCategories() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('cars').get();
      Set<String> categories = {};

      for (var doc in snapshot.docs) {
        String category = (doc.data() as Map<String, dynamic>)['category'];
        categories.add(category);
      }

      return categories.toList();
    } catch (e) {
      throw 'Failed to get categories: $e';
    }
  }
}

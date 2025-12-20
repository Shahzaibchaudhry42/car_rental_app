import 'package:cloud_firestore/cloud_firestore.dart';

/// Booking status enum
enum BookingStatus { pending, approved, cancelled, completed, rejected }

/// Booking model representing car reservations
class BookingModel {
  final String id;
  final String userId;
  final String carId;
  final String carName;
  final String carImageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final BookingStatus status;
  final String? paymentId;
  final bool isPaid;
  final String pickupLocation;
  final String dropoffLocation;
  final String? specialRequests;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminNote;

  BookingModel({
    required this.id,
    required this.userId,
    required this.carId,
    required this.carName,
    required this.carImageUrl,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    this.status = BookingStatus.pending,
    this.paymentId,
    this.isPaid = false,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.specialRequests,
    required this.createdAt,
    this.updatedAt,
    this.adminNote,
  });

  /// Calculate number of days for the booking
  int get numberOfDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Create BookingModel from Firestore document
  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      carId: data['carId'] ?? '',
      carName: data['carName'] ?? '',
      carImageUrl: data['carImageUrl'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      status: _statusFromString(data['status'] ?? 'pending'),
      paymentId: data['paymentId'],
      isPaid: data['isPaid'] ?? false,
      pickupLocation: data['pickupLocation'] ?? '',
      dropoffLocation: data['dropoffLocation'] ?? '',
      specialRequests: data['specialRequests'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      adminNote: data['adminNote'],
    );
  }

  /// Convert BookingModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'carId': carId,
      'carName': carName,
      'carImageUrl': carImageUrl,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalPrice': totalPrice,
      'status': status.toString().split('.').last,
      'paymentId': paymentId,
      'isPaid': isPaid,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'specialRequests': specialRequests,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'adminNote': adminNote,
    };
  }

  /// Convert string to BookingStatus
  static BookingStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return BookingStatus.approved;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'completed':
        return BookingStatus.completed;
      case 'rejected':
        return BookingStatus.rejected;
      default:
        return BookingStatus.pending;
    }
  }

  /// Create a copy of BookingModel with updated fields
  BookingModel copyWith({
    String? id,
    String? userId,
    String? carId,
    String? carName,
    String? carImageUrl,
    DateTime? startDate,
    DateTime? endDate,
    double? totalPrice,
    BookingStatus? status,
    String? paymentId,
    bool? isPaid,
    String? pickupLocation,
    String? dropoffLocation,
    String? specialRequests,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminNote,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      carId: carId ?? this.carId,
      carName: carName ?? this.carName,
      carImageUrl: carImageUrl ?? this.carImageUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      isPaid: isPaid ?? this.isPaid,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      specialRequests: specialRequests ?? this.specialRequests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}

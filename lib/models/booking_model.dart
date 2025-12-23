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

  /// The date/time the booking was created (also stored as `bookingDate` in Firestore).
  final DateTime bookingDate;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final BookingStatus status;
  final String? paymentId;
  final bool isPaid;

  /// Convenience string fields requested by the app spec.
  /// Stored in Firestore as `paymentStatus` (paid/unpaid) and `bookingStatus` (pending/completed/cancelled).
  final String paymentStatus;
  final String bookingStatus;

  /// Stored for email confirmations (Cloud Functions uses these to send booking emails).
  final String? userName;
  final String? userEmail;
  final Map<String, dynamic>? billingDetails;

  /// Email idempotency fields.
  final bool emailSent;
  final DateTime? emailSentAt;
  final String? emailSendState;
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
    DateTime? bookingDate,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    this.status = BookingStatus.pending,
    this.paymentId,
    this.isPaid = false,
    String? paymentStatus,
    String? bookingStatus,
    this.userName,
    this.userEmail,
    this.billingDetails,
    this.emailSent = false,
    this.emailSentAt,
    this.emailSendState,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.specialRequests,
    required this.createdAt,
    this.updatedAt,
    this.adminNote,
  }) : bookingDate = bookingDate ?? createdAt,
       paymentStatus = (paymentStatus ?? (isPaid ? 'paid' : 'unpaid')),
       bookingStatus = (bookingStatus ?? _deriveBookingStatus(status));

  /// Calculate number of days for the booking
  int get numberOfDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Create BookingModel from Firestore document
  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final status = _statusFromString(data['status'] ?? 'pending');
    final isPaid = data['isPaid'] ?? false;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      carId: data['carId'] ?? '',
      carName: data['carName'] ?? '',
      carImageUrl: data['carImageUrl'] ?? '',
      bookingDate: data['bookingDate'] != null
          ? (data['bookingDate'] as Timestamp).toDate()
          : (data['createdAt'] as Timestamp).toDate(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      status: status,
      paymentId: data['paymentId'],
      isPaid: isPaid,
      paymentStatus: (data['paymentStatus'] ?? (isPaid ? 'paid' : 'unpaid'))
          .toString(),
      bookingStatus: (data['bookingStatus'] ?? _deriveBookingStatus(status))
          .toString(),
      userName: data['userName'],
      userEmail: data['userEmail'],
      billingDetails: (data['billingDetails'] is Map)
          ? Map<String, dynamic>.from(data['billingDetails'] as Map)
          : null,
      emailSent: data['emailSent'] ?? false,
      emailSentAt: data['emailSentAt'] != null
          ? (data['emailSentAt'] as Timestamp).toDate()
          : null,
      emailSendState: data['emailSendState'],
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
      'bookingDate': Timestamp.fromDate(bookingDate),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalPrice': totalPrice,
      'status': status.toString().split('.').last,
      'paymentId': paymentId,
      'isPaid': isPaid,
      'paymentStatus': paymentStatus,
      'bookingStatus': bookingStatus,
      if (userName != null) 'userName': userName,
      if (userEmail != null) 'userEmail': userEmail,
      if (billingDetails != null) 'billingDetails': billingDetails,
      'emailSent': emailSent,
      if (emailSentAt != null) 'emailSentAt': Timestamp.fromDate(emailSentAt!),
      if (emailSendState != null) 'emailSendState': emailSendState,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'specialRequests': specialRequests,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'adminNote': adminNote,
    };
  }

  static String _deriveBookingStatus(BookingStatus status) {
    switch (status) {
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.completed:
        return 'completed';
      default:
        return 'pending';
    }
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
    DateTime? bookingDate,
    DateTime? startDate,
    DateTime? endDate,
    double? totalPrice,
    BookingStatus? status,
    String? paymentId,
    bool? isPaid,
    String? paymentStatus,
    String? bookingStatus,
    String? userName,
    String? userEmail,
    Map<String, dynamic>? billingDetails,
    bool? emailSent,
    DateTime? emailSentAt,
    String? emailSendState,
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
      bookingDate: bookingDate ?? this.bookingDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      isPaid: isPaid ?? this.isPaid,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      billingDetails: billingDetails ?? this.billingDetails,
      emailSent: emailSent ?? this.emailSent,
      emailSentAt: emailSentAt ?? this.emailSentAt,
      emailSendState: emailSendState ?? this.emailSendState,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      specialRequests: specialRequests ?? this.specialRequests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}

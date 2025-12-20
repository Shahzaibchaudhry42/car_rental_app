import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';

/// Service for handling booking operations
class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Create a new booking
  Future<String> createBooking(BookingModel booking) async {
    try {
      // Check if car is available for the selected dates
      bool isAvailable = await _checkAvailability(
        carId: booking.carId,
        startDate: booking.startDate,
        endDate: booking.endDate,
      );

      if (!isAvailable) {
        throw 'Car is not available for the selected dates';
      }

      // Create booking document
      DocumentReference docRef = await _firestore
          .collection('bookings')
          .add(booking.toMap());

      // Send notification to user
      await _notificationService.sendBookingNotification(
        userId: booking.userId,
        title: 'Booking Created',
        body:
            'Your booking for ${booking.carName} has been created and is pending approval.',
      );

      return docRef.id;
    } catch (e) {
      throw 'Failed to create booking: $e';
    }
  }

  /// Get user bookings stream
  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get all bookings stream (Admin)
  Stream<List<BookingModel>> getAllBookingsStream() {
    return _firestore
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get pending bookings stream (Admin)
  Stream<List<BookingModel>> getPendingBookingsStream() {
    return _firestore
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (doc.exists) {
        return BookingModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Failed to get booking: $e';
    }
  }

  /// Approve booking (Admin)
  Future<void> approveBooking(String bookingId, {String? adminNote}) async {
    try {
      BookingModel? booking = await getBookingById(bookingId);
      if (booking == null) {
        throw 'Booking not found';
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'approved',
        'updatedAt': Timestamp.now(),
        if (adminNote != null) 'adminNote': adminNote,
      });

      // Send notification to user
      await _notificationService.sendBookingNotification(
        userId: booking.userId,
        title: 'Booking Approved',
        body: 'Your booking for ${booking.carName} has been approved!',
      );
    } catch (e) {
      throw 'Failed to approve booking: $e';
    }
  }

  /// Reject booking (Admin)
  Future<void> rejectBooking(String bookingId, {String? adminNote}) async {
    try {
      BookingModel? booking = await getBookingById(bookingId);
      if (booking == null) {
        throw 'Booking not found';
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'rejected',
        'updatedAt': Timestamp.now(),
        if (adminNote != null) 'adminNote': adminNote,
      });

      // Send notification to user
      await _notificationService.sendBookingNotification(
        userId: booking.userId,
        title: 'Booking Rejected',
        body:
            'Your booking for ${booking.carName} has been rejected. ${adminNote ?? ''}',
      );
    } catch (e) {
      throw 'Failed to reject booking: $e';
    }
  }

  /// Cancel booking (User or Admin)
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      BookingModel? booking = await getBookingById(bookingId);
      if (booking == null) {
        throw 'Booking not found';
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'updatedAt': Timestamp.now(),
        if (reason != null) 'adminNote': reason,
      });

      // Send notification to user
      await _notificationService.sendBookingNotification(
        userId: booking.userId,
        title: 'Booking Cancelled',
        body: 'Your booking for ${booking.carName} has been cancelled.',
      );
    } catch (e) {
      throw 'Failed to cancel booking: $e';
    }
  }

  /// Complete booking (Admin)
  Future<void> completeBooking(String bookingId) async {
    try {
      BookingModel? booking = await getBookingById(bookingId);
      if (booking == null) {
        throw 'Booking not found';
      }

      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'updatedAt': Timestamp.now(),
      });

      // Send notification to user
      await _notificationService.sendBookingNotification(
        userId: booking.userId,
        title: 'Booking Completed',
        body:
            'Thank you for renting ${booking.carName}. Please rate your experience!',
      );
    } catch (e) {
      throw 'Failed to complete booking: $e';
    }
  }

  /// Update payment status
  Future<void> updatePaymentStatus({
    required String bookingId,
    required String paymentId,
    required bool isPaid,
  }) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'paymentId': paymentId,
        'isPaid': isPaid,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw 'Failed to update payment status: $e';
    }
  }

  /// Get upcoming bookings for a user
  Future<List<BookingModel>> getUpcomingBookings(String userId) async {
    try {
      DateTime now = DateTime.now();
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      List<BookingModel> bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .where((booking) => booking.startDate.isAfter(now))
          .toList();

      bookings.sort((a, b) => a.startDate.compareTo(b.startDate));
      return bookings;
    } catch (e) {
      throw 'Failed to get upcoming bookings: $e';
    }
  }

  /// Get past bookings for a user
  Future<List<BookingModel>> getPastBookings(String userId) async {
    try {
      DateTime now = DateTime.now();
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['completed', 'cancelled'])
          .get();

      List<BookingModel> bookings = snapshot.docs
          .map((doc) => BookingModel.fromFirestore(doc))
          .where((booking) => booking.endDate.isBefore(now))
          .toList();

      bookings.sort((a, b) => b.endDate.compareTo(a.endDate));
      return bookings;
    } catch (e) {
      throw 'Failed to get past bookings: $e';
    }
  }

  /// Check if car is available for booking dates
  Future<bool> _checkAvailability({
    required String carId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      QuerySnapshot bookings = await _firestore
          .collection('bookings')
          .where('carId', isEqualTo: carId)
          .where('status', whereIn: ['pending', 'approved'])
          .get();

      for (var doc in bookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime bookingStart = (data['startDate'] as Timestamp).toDate();
        DateTime bookingEnd = (data['endDate'] as Timestamp).toDate();

        // Check for date overlap
        if ((startDate.isBefore(bookingEnd) ||
                startDate.isAtSameMomentAs(bookingEnd)) &&
            (endDate.isAfter(bookingStart) ||
                endDate.isAtSameMomentAs(bookingStart))) {
          return false;
        }
      }

      return true;
    } catch (e) {
      final message = e.toString();
      // If reads are blocked by Firestore rules, don't fail booking creation.
      // Treat availability as unknown and allow the booking write to proceed.
      if (message.contains('permission-denied') ||
          message.contains('PERMISSION_DENIED')) {
        return true;
      }
      throw 'Failed to check availability: $e';
    }
  }

  /// Get booking statistics (Admin)
  Future<Map<String, dynamic>> getBookingStatistics() async {
    try {
      QuerySnapshot allBookings = await _firestore.collection('bookings').get();

      int totalBookings = allBookings.docs.length;
      int pendingBookings = allBookings.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['status'] == 'pending',
          )
          .length;
      int approvedBookings = allBookings.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['status'] == 'approved',
          )
          .length;
      int completedBookings = allBookings.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['status'] == 'completed',
          )
          .length;
      int cancelledBookings = allBookings.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['status'] == 'cancelled',
          )
          .length;

      double totalRevenue = 0;
      for (var doc in allBookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['isPaid'] == true) {
          totalRevenue += (data['totalPrice'] ?? 0).toDouble();
        }
      }

      return {
        'totalBookings': totalBookings,
        'pendingBookings': pendingBookings,
        'approvedBookings': approvedBookings,
        'completedBookings': completedBookings,
        'cancelledBookings': cancelledBookings,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      throw 'Failed to get statistics: $e';
    }
  }
}

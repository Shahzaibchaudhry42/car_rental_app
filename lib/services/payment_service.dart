import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'booking_service.dart';

/// Service for handling payment operations
class PaymentService {
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: '',
  );

  late Razorpay _razorpay;
  final BookingService _bookingService = BookingService();

  bool get isConfigured => razorpayKey.trim().isNotEmpty;

  /// Initialize Razorpay
  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
      onSuccess(response as PaymentSuccessResponse);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
      onFailure(response as PaymentFailureResponse);
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
      onExternalWallet(response as ExternalWalletResponse);
    });
  }

  /// Open Razorpay checkout
  void openCheckout({
    required double amount,
    required String name,
    required String description,
    required String email,
    required String contact,
  }) {
    if (!isConfigured) {
      throw 'Razorpay is not configured. Provide `--dart-define=RAZORPAY_KEY=...`.';
    }

    var options = {
      'key': razorpayKey,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': 'Car Rental App',
      'description': description,
      'prefill': {'contact': contact, 'email': email},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      throw 'Failed to open checkout: $e';
    }
  }

  /// Process payment success
  Future<void> processPaymentSuccess({
    required String bookingId,
    required String paymentId,
    String? userName,
    String? userEmail,
    Map<String, dynamic>? billingDetails,
  }) async {
    try {
      await _bookingService.completeBookingAfterPayment(
        bookingId: bookingId,
        paymentId: paymentId,
        userName: userName,
        userEmail: userEmail,
        billingDetails: billingDetails,
      );
    } catch (e) {
      throw 'Failed to process payment: $e';
    }
  }

  /// Dispose Razorpay
  void dispose() {
    _razorpay.clear();
  }

  /// Calculate booking price
  double calculateBookingPrice({
    required double pricePerDay,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    int days = endDate.difference(startDate).inDays + 1;
    return pricePerDay * days;
  }

  /// Apply discount
  double applyDiscount({
    required double originalPrice,
    required double discountPercentage,
  }) {
    double discount = originalPrice * (discountPercentage / 100);
    return originalPrice - discount;
  }

  /// Calculate tax
  double calculateTax({required double amount, required double taxPercentage}) {
    return amount * (taxPercentage / 100);
  }

  /// Calculate total amount including tax
  double calculateTotalAmount({
    required double baseAmount,
    double taxPercentage = 18.0, // Default GST in India
    double discountPercentage = 0.0,
  }) {
    double amountAfterDiscount = applyDiscount(
      originalPrice: baseAmount,
      discountPercentage: discountPercentage,
    );
    double tax = calculateTax(
      amount: amountAfterDiscount,
      taxPercentage: taxPercentage,
    );
    return amountAfterDiscount + tax;
  }
}

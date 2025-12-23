import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../models/car_model.dart';
import '../services/payment_service.dart';
import '../services/booking_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Payment screen for processing car rental payments
class PaymentScreen extends StatefulWidget {
  /// When provided, PaymentScreen updates payment status for an existing booking.
  /// When null, PaymentScreen will create a new booking after payment.
  final String? bookingId;
  final CarModel car;
  final DateTime startDate;
  final DateTime endDate;
  final String pickupLocation;
  final String dropoffLocation;
  final String? specialRequests;
  final double totalPrice;

  const PaymentScreen({
    super.key,
    this.bookingId,
    required this.car,
    required this.startDate,
    required this.endDate,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.specialRequests,
    required this.totalPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final PaymentService _paymentService = PaymentService();
  final BookingService _bookingService = BookingService();

  // Payment method
  String _selectedPaymentMethod = 'razorpay';

  // Card details
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  // UPI details
  final TextEditingController _upiIdController = TextEditingController();

  // Coupon
  final TextEditingController _couponController = TextEditingController();
  double _discount = 0;
  bool _isCouponApplied = false;

  // Billing details (requested)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // On web, razorpay_flutter may not be supported and can lead to blank screens.
    // Default to a non-Razorpay option and skip initializing the plugin.
    if (kIsWeb) {
      _selectedPaymentMethod = 'card';
    } else {
      _paymentService.initialize(
        onSuccess: _handlePaymentSuccess,
        onFailure: _handlePaymentFailure,
        onExternalWallet: _handleExternalWallet,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _upiIdController.dispose();
    _couponController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  /// Calculate final price after discount
  double get _finalPrice => widget.totalPrice - _discount;

  /// Apply coupon code
  void _applyCoupon() {
    final couponCode = _couponController.text.trim().toUpperCase();

    if (couponCode.isEmpty) {
      _showSnackBar('Please enter a coupon code', isError: true);
      return;
    }

    // Sample coupon codes (in real app, validate from backend)
    final Map<String, double> coupons = {
      'FIRST10': 10, // 10% off
      'SAVE20': 20, // 20% off
      'WELCOME15': 15, // 15% off
      'FLAT50': 50, // Flat 50 off
    };

    if (coupons.containsKey(couponCode)) {
      setState(() {
        if (couponCode == 'FLAT50') {
          _discount = 50;
        } else {
          _discount = widget.totalPrice * (coupons[couponCode]! / 100);
        }
        _isCouponApplied = true;
      });
      _showSnackBar(
        'Coupon applied successfully! You saved ₹${_discount.toStringAsFixed(2)}',
      );
    } else {
      _showSnackBar('Invalid coupon code', isError: true);
    }
  }

  /// Remove applied coupon
  void _removeCoupon() {
    setState(() {
      _discount = 0;
      _isCouponApplied = false;
      _couponController.clear();
    });
    _showSnackBar('Coupon removed');
  }

  /// Process payment
  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User not authenticated';
      }

      if (_selectedPaymentMethod == 'razorpay') {
        // Process via Razorpay
        _processRazorpayPayment(user);
      } else {
        // Process other payment methods
        await _processOtherPayment(user);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      final message = e.toString();
      final isPermissionDenied =
          message.contains('permission-denied') ||
          message.contains('PERMISSION_DENIED');
      _showSnackBar(
        isPermissionDenied
            ? 'Payment could not update booking due to Firestore permissions. Deploy firestore.rules and retry.'
            : 'Payment failed: $e',
        isError: true,
      );
    }
  }

  /// Process Razorpay payment
  void _processRazorpayPayment(User user) {
    if (kIsWeb) {
      setState(() => _isProcessing = false);
      _showDialog(
        title: 'Not Supported on Web',
        message:
            'Razorpay checkout is not supported on web in this app build. Please choose Card/UPI/Net Banking.',
        isError: true,
      );
      return;
    }

    if (!_paymentService.isConfigured) {
      setState(() => _isProcessing = false);
      _showDialog(
        title: 'Razorpay Not Configured',
        message:
            'Razorpay payment gateway is not configured. Please use another payment method or contact support.',
        isError: true,
      );
      return;
    }

    try {
      _paymentService.openCheckout(
        amount: _finalPrice,
        name: widget.car.name,
        description:
            'Car rental from ${DateFormat('MMM dd').format(widget.startDate)} to ${DateFormat('MMM dd').format(widget.endDate)}',
        email: user.email ?? 'customer@example.com',
        contact: user.phoneNumber ?? '9999999999',
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Failed to open Razorpay: $e', isError: true);
    }
  }

  /// Process other payment methods
  Future<void> _processOtherPayment(User user) async {
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    try {
      final paymentId =
          'pay_${_selectedPaymentMethod}_${DateTime.now().millisecondsSinceEpoch}';

      // If bookingId was provided (from BookingScreen), just mark it paid.
      // Otherwise create a new booking now.
      String bookingId;
      if (widget.bookingId != null && widget.bookingId!.trim().isNotEmpty) {
        bookingId = widget.bookingId!;
        await _paymentService.processPaymentSuccess(
          bookingId: bookingId,
          paymentId: paymentId,
          userName: _fullNameFromBilling().isNotEmpty
              ? _fullNameFromBilling()
              : (user.displayName ?? ''),
          userEmail: user.email,
          billingDetails: _buildBillingDetailsMap(),
        );
      } else {
        final booking = BookingModel(
          id: '',
          userId: user.uid,
          carId: widget.car.id,
          carName: widget.car.name,
          carImageUrl: widget.car.imageUrl.isNotEmpty
              ? widget.car.imageUrl
              : 'https://via.placeholder.com/150',
          startDate: widget.startDate,
          endDate: widget.endDate,
          totalPrice: _finalPrice,
          status: BookingStatus.completed,
          paymentId: paymentId,
          isPaid: true,
          paymentStatus: 'paid',
          bookingStatus: 'completed',
          userName: _fullNameFromBilling().isNotEmpty
              ? _fullNameFromBilling()
              : (user.displayName ?? ''),
          userEmail: user.email,
          billingDetails: _buildBillingDetailsMap(),
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          specialRequests: widget.specialRequests,
          createdAt: DateTime.now(),
        );
        bookingId = await _bookingService.createBooking(booking);
      }
      setState(() => _isProcessing = false);
      _showSuccessDialog(bookingId);
    } catch (e) {
      setState(() => _isProcessing = false);
      rethrow;
    }
  }

  /// Handle Razorpay payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User not authenticated';
      }

      final paymentId = response.paymentId ?? '';

      // Update existing booking if provided, else create a new one.
      String bookingId;
      if (widget.bookingId != null && widget.bookingId!.trim().isNotEmpty) {
        bookingId = widget.bookingId!;
        await _paymentService.processPaymentSuccess(
          bookingId: bookingId,
          paymentId: paymentId,
          userName: _fullNameFromBilling().isNotEmpty
              ? _fullNameFromBilling()
              : (user.displayName ?? ''),
          userEmail: user.email,
          billingDetails: _buildBillingDetailsMap(),
        );
      } else {
        final booking = BookingModel(
          id: '',
          userId: user.uid,
          carId: widget.car.id,
          carName: widget.car.name,
          carImageUrl: widget.car.imageUrl.isNotEmpty
              ? widget.car.imageUrl
              : 'https://via.placeholder.com/150',
          startDate: widget.startDate,
          endDate: widget.endDate,
          totalPrice: _finalPrice,
          status: BookingStatus.completed,
          paymentId: paymentId,
          isPaid: true,
          paymentStatus: 'paid',
          bookingStatus: 'completed',
          userName: _fullNameFromBilling().isNotEmpty
              ? _fullNameFromBilling()
              : (user.displayName ?? ''),
          userEmail: user.email,
          billingDetails: _buildBillingDetailsMap(),
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          specialRequests: widget.specialRequests,
          createdAt: DateTime.now(),
        );
        bookingId = await _bookingService.createBooking(booking);
      }
      setState(() => _isProcessing = false);
      _showSuccessDialog(bookingId);
    } catch (e) {
      setState(() => _isProcessing = false);
      final message = e.toString();
      final isPermissionDenied =
          message.contains('permission-denied') ||
          message.contains('PERMISSION_DENIED');
      _showSnackBar(
        isPermissionDenied
            ? 'Payment captured, but booking update was blocked by Firestore rules. Deploy firestore.rules and try again.'
            : 'Failed to create booking: $e',
        isError: true,
      );
    }
  }

  /// Handle Razorpay payment failure
  void _handlePaymentFailure(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    _showDialog(
      title: 'Payment Failed',
      message: response.message ?? 'Payment failed. Please try again.',
      isError: true,
    );
  }

  /// Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessing = false);
    _showSnackBar('External wallet selected: ${response.walletName}');
  }

  /// Show success dialog
  void _showSuccessDialog(String bookingId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful!', style: TextStyle(fontSize: 22)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your booking has been confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Booking ID',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookingId.substring(0, 8).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close payment screen
              Navigator.of(context).pop(); // Close booking screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Show dialog
  void _showDialog({
    required String title,
    required String message,
    bool isError = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Map<String, dynamic> _buildBillingDetailsMap() {
    return {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'addressLine1': _addressLine1Controller.text.trim(),
      'addressLine2': _addressLine2Controller.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
    };
  }

  String _fullNameFromBilling() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return [first, last].where((p) => p.isNotEmpty).join(' ');
  }

  Widget _buildBillingDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressLine1Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 1',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Address is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressLine2Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 2 (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Town / City',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'City is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'Country/State...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'State is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postalCodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Postal Code',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Postal code is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Payment'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookingSummary(),
                    const SizedBox(height: 24),
                    _buildBillingDetailsSection(),
                    const SizedBox(height: 24),
                    _buildCouponSection(),
                    const SizedBox(height: 24),
                    _buildPriceBreakdown(),
                    const SizedBox(height: 24),
                    _buildPaymentMethodSelection(),
                    const SizedBox(height: 24),
                    _buildPaymentForm(),
                    const SizedBox(height: 24),
                    _buildPayButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing payment...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build booking summary
  Widget _buildBookingSummary() {
    final numberOfDays = widget.endDate.difference(widget.startDate).inDays + 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.car.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.car.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(Icons.directions_car),
                              ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.directions_car),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.car.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.car.brand} • ${widget.car.year}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              icon: Icons.calendar_today,
              label: 'Pickup',
              value: DateFormat('MMM dd, yyyy').format(widget.startDate),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              icon: Icons.calendar_today,
              label: 'Return',
              value: DateFormat('MMM dd, yyyy').format(widget.endDate),
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              icon: Icons.access_time,
              label: 'Duration',
              value: '$numberOfDays ${numberOfDays == 1 ? 'day' : 'days'}',
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              icon: Icons.location_on,
              label: 'Pickup Location',
              value: widget.pickupLocation,
            ),
          ],
        ),
      ),
    );
  }

  /// Build summary row
  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Build coupon section
  Widget _buildCouponSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Apply Coupon',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _couponController,
                    enabled: !_isCouponApplied,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isCouponApplied ? _removeCoupon : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCouponApplied
                        ? Colors.red
                        : Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_isCouponApplied ? 'Remove' : 'Apply'),
                ),
              ],
            ),
            if (_isCouponApplied)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '✓ Coupon applied! You saved ₹${_discount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build price breakdown
  Widget _buildPriceBreakdown() {
    final numberOfDays = widget.endDate.difference(widget.startDate).inDays + 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPriceRow(
              'Base price (₹${widget.car.pricePerDay.toStringAsFixed(0)}/day × $numberOfDays days)',
              '₹${widget.totalPrice.toStringAsFixed(2)}',
            ),
            if (_discount > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow(
                'Discount',
                '- ₹${_discount.toStringAsFixed(2)}',
                color: Colors.green,
              ),
            ],
            const Divider(height: 24),
            _buildPriceRow(
              'Total Amount',
              '₹${_finalPrice.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Build price row
  Widget _buildPriceRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build payment method selection
  Widget _buildPaymentMethodSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (!kIsWeb)
              _buildPaymentOption(
                value: 'razorpay',
                title: 'Razorpay',
                subtitle: 'Pay with Razorpay (Recommended)',
                icon: Icons.payment,
              ),
            _buildPaymentOption(
              value: 'card',
              title: 'Credit/Debit Card',
              subtitle: 'Visa, Mastercard, Rupay',
              icon: Icons.credit_card,
            ),
            _buildPaymentOption(
              value: 'upi',
              title: 'UPI',
              subtitle: 'Google Pay, PhonePe, Paytm',
              icon: Icons.account_balance_wallet,
            ),
            _buildPaymentOption(
              value: 'netbanking',
              title: 'Net Banking',
              subtitle: 'All major banks',
              icon: Icons.account_balance,
            ),
          ],
        ),
      ),
    );
  }

  /// Build payment option
  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: _selectedPaymentMethod,
      onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
      title: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Build payment form
  Widget _buildPaymentForm() {
    if (_selectedPaymentMethod == 'razorpay') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getPaymentMethodTitle()} Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedPaymentMethod == 'card') ..._buildCardForm(),
            if (_selectedPaymentMethod == 'upi') ..._buildUpiForm(),
            if (_selectedPaymentMethod == 'netbanking')
              ..._buildNetBankingForm(),
          ],
        ),
      ),
    );
  }

  /// Get payment method title
  String _getPaymentMethodTitle() {
    switch (_selectedPaymentMethod) {
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      default:
        return 'Payment';
    }
  }

  /// Build card form
  List<Widget> _buildCardForm() {
    return [
      TextFormField(
        controller: _cardNumberController,
        decoration: InputDecoration(
          labelText: 'Card Number',
          hintText: '1234 5678 9012 3456',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.credit_card),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(16),
          _CardNumberFormatter(),
        ],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter card number';
          }
          if (value.replaceAll(' ', '').length != 16) {
            return 'Card number must be 16 digits';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cardHolderController,
        decoration: InputDecoration(
          labelText: 'Card Holder Name',
          hintText: 'John Doe',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.person),
        ),
        textCapitalization: TextCapitalization.words,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter card holder name';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _expiryController,
              decoration: InputDecoration(
                labelText: 'Expiry Date',
                hintText: 'MM/YY',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
                _ExpiryDateFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (value.length != 5) {
                  return 'Invalid';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _cvvController,
              decoration: InputDecoration(
                labelText: 'CVV',
                hintText: '123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (value.length != 3) {
                  return 'Invalid';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    ];
  }

  /// Build UPI form
  List<Widget> _buildUpiForm() {
    return [
      TextFormField(
        controller: _upiIdController,
        decoration: InputDecoration(
          labelText: 'UPI ID',
          hintText: 'example@upi',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.account_balance_wallet),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter UPI ID';
          }
          if (!value.contains('@')) {
            return 'Invalid UPI ID';
          }
          return null;
        },
      ),
    ];
  }

  /// Build net banking form
  List<Widget> _buildNetBankingForm() {
    return [
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Select Bank',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.account_balance),
        ),
        items: const [
          DropdownMenuItem(value: 'sbi', child: Text('State Bank of India')),
          DropdownMenuItem(value: 'hdfc', child: Text('HDFC Bank')),
          DropdownMenuItem(value: 'icici', child: Text('ICICI Bank')),
          DropdownMenuItem(value: 'axis', child: Text('Axis Bank')),
          DropdownMenuItem(value: 'kotak', child: Text('Kotak Mahindra Bank')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a bank';
          }
          return null;
        },
        onChanged: (value) {},
      ),
    ];
  }

  /// Build pay button
  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: Text(
          'Pay ₹${_finalPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Card number formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

/// Expiry date formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.length > 2 && !text.contains('/')) {
      return TextEditingValue(
        text: '${text.substring(0, 2)}/${text.substring(2)}',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    }

    return newValue;
  }
}

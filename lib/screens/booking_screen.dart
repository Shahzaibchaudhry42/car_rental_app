import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/car_model.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/car_service.dart';
import '../services/payment_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Booking screen for car reservation
class BookingScreen extends StatefulWidget {
  final CarModel car;

  const BookingScreen({super.key, required this.car});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final BookingService _bookingService = BookingService();
  final CarService _carService = CarService();
  final PaymentService _paymentService = PaymentService();

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _specialRequestsController =
      TextEditingController();

  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  bool _isAvailable = true;
  bool _animate = false;
  int _numberOfDays = 0;
  double _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    _pickupController.text = widget.car.location;
    _dropoffController.text = widget.car.location;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _animate = true;
        });
      }
    });

    // Initialize Razorpay
    _paymentService.initialize(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
      onExternalWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _specialRequestsController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  /// Select start date
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
        _calculatePrice();
      });
      _checkAvailability();
    }
  }

  /// Select end date
  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date first')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _calculatePrice();
      });
      _checkAvailability();
    }
  }

  /// Calculate total price
  void _calculatePrice() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _numberOfDays = _endDate!.difference(_startDate!).inDays + 1;
        _totalPrice = _paymentService.calculateTotalAmount(
          baseAmount: widget.car.pricePerDay * _numberOfDays,
        );
      });
    }
  }

  /// Check car availability
  Future<void> _checkAvailability() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isCheckingAvailability = true);

    try {
      bool available = await _carService.checkCarAvailability(
        carId: widget.car.id,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      setState(() {
        _isAvailable = available;
      });

      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Car is not available for selected dates'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking availability: $e')),
      );
    } finally {
      setState(() => _isCheckingAvailability = false);
    }
  }

  /// Create booking
  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select booking dates')),
      );
      return;
    }

    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Car is not available for selected dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'Please login to book a car';
      }

      // Create booking
      BookingModel booking = BookingModel(
        id: '',
        userId: user.uid,
        carId: widget.car.id,
        carName: widget.car.name,
        carImageUrl: widget.car.imageUrl,
        startDate: _startDate!,
        endDate: _endDate!,
        totalPrice: _totalPrice,
        pickupLocation: _pickupController.text.trim(),
        dropoffLocation: _dropoffController.text.trim(),
        specialRequests: _specialRequestsController.text.trim().isNotEmpty
            ? _specialRequestsController.text.trim()
            : null,
        createdAt: DateTime.now(),
      );

      String bookingId = await _bookingService.createBooking(booking);

      // For web (where Razorpay Flutter isn't supported well),
      // simulate a successful payment to keep the flow working.
      if (kIsWeb) {
        await _paymentService.processPaymentSuccess(
          bookingId: bookingId,
          paymentId: 'WEB_TEST_PAYMENT',
        );
        _onBookingSuccess();
      } else {
        // Open payment gateway on supported platforms
        _paymentService.openCheckout(
          amount: _totalPrice,
          name: user.displayName ?? 'User',
          description: 'Booking for ${widget.car.name}',
          email: user.email ?? '',
          contact: user.phoneNumber ?? '',
        );

        // Store booking ID for payment callback
        _currentBookingId = bookingId;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _currentBookingId = '';

  /// Common success flow after payment is confirmed
  void _onBookingSuccess() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking created successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
    Navigator.pop(context);
  }

  /// Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await _paymentService.processPaymentSuccess(
        bookingId: _currentBookingId,
        paymentId: response.paymentId ?? '',
      );

      _onBookingSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Handle payment failure
  void _handlePaymentFailure(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Handle external wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Car')),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                offset: _animate ? Offset.zero : const Offset(0, 0.05),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _animate ? 1 : 0,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Car info card
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    widget.car.imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.directions_car),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        '${widget.car.brand} ${widget.car.model}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '₹${widget.car.pricePerDay.toStringAsFixed(0)}/day',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Booking dates
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Booking Dates',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Start date
                                InkWell(
                                  onTap: _selectStartDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      _startDate == null
                                          ? 'Select start date'
                                          : DateFormat(
                                              'MMM dd, yyyy',
                                            ).format(_startDate!),
                                      style: TextStyle(
                                        color: _startDate == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // End date
                                InkWell(
                                  onTap: _selectEndDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'End Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      _endDate == null
                                          ? 'Select end date'
                                          : DateFormat(
                                              'MMM dd, yyyy',
                                            ).format(_endDate!),
                                      style: TextStyle(
                                        color: _endDate == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Location details
                        const Text(
                          'Location Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _pickupController,
                          decoration: const InputDecoration(
                            labelText: 'Pickup Location',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter pickup location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _dropoffController,
                          decoration: const InputDecoration(
                            labelText: 'Drop-off Location',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter drop-off location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Special requests
                        const Text(
                          'Special Requests (Optional)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _specialRequestsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Any special requirements?',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Price summary
                        if (_startDate != null && _endDate != null)
                          Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'Price Summary',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(height: 24),
                                  _buildPriceRow(
                                    'Price per day',
                                    '₹${widget.car.pricePerDay.toStringAsFixed(0)}',
                                  ),
                                  _buildPriceRow(
                                    'Number of days',
                                    _numberOfDays.toString(),
                                  ),
                                  _buildPriceRow(
                                    'Subtotal',
                                    '₹${(widget.car.pricePerDay * _numberOfDays).toStringAsFixed(0)}',
                                  ),
                                  _buildPriceRow(
                                    'Tax (18%)',
                                    '₹${(_totalPrice - (widget.car.pricePerDay * _numberOfDays)).toStringAsFixed(0)}',
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '₹${_totalPrice.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 80), // Space for bottom button
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing your booking...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Confirm booking button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (_isLoading || _isCheckingAvailability || !_isAvailable)
              ? null
              : _createBooking,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Confirm & Pay',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  /// Build price row
  Widget _buildPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/car_service.dart';
import '../models/car_model.dart';
import 'package:uuid/uuid.dart';

/// Screen for adding or editing cars (Admin)
class AddEditCarScreen extends StatefulWidget {
  final CarModel? car;

  const AddEditCarScreen({super.key, this.car});

  @override
  State<AddEditCarScreen> createState() => _AddEditCarScreenState();
}

class _AddEditCarScreenState extends State<AddEditCarScreen> {
  final _formKey = GlobalKey<FormState>();
  final CarService _carService = CarService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  late TextEditingController _imageUrlController;

  String _selectedCategory = 'Sedan';
  String _selectedFuelType = 'Petrol';
  String _selectedTransmission = 'Manual';
  int _seatingCapacity = 4;
  List<String> _features = [];
  final TextEditingController _featureController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;

  final List<String> _categories = [
    'Sedan',
    'SUV',
    'Hatchback',
    'Luxury',
    'Sports',
    'Electric',
  ];

  final List<String> _fuelTypes = [
    'Petrol',
    'Diesel',
    'Electric',
    'Hybrid',
    'CNG',
  ];

  final List<String> _transmissions = ['Manual', 'Automatic'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.car?.name);
    _brandController = TextEditingController(text: widget.car?.brand);
    _modelController = TextEditingController(text: widget.car?.model);
    _yearController = TextEditingController(
      text: widget.car?.year.toString() ?? DateTime.now().year.toString(),
    );
    _priceController = TextEditingController(
      text: widget.car?.pricePerDay.toStringAsFixed(0),
    );
    _locationController = TextEditingController(text: widget.car?.location);
    _imageUrlController = TextEditingController(text: widget.car?.imageUrl);

    if (widget.car != null) {
      _selectedCategory = widget.car!.category;
      _selectedFuelType = widget.car!.fuelType;
      _selectedTransmission = widget.car!.transmission;
      _seatingCapacity = widget.car!.seatingCapacity;
      _features = List.from(widget.car!.features);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  /// Add feature
  void _addFeature() {
    if (_featureController.text.trim().isNotEmpty) {
      setState(() {
        _features.add(_featureController.text.trim());
        _featureController.clear();
      });
    }
  }

  /// Remove feature
  void _removeFeature(int index) {
    setState(() {
      _features.removeAt(index);
    });
  }

  /// Save car
  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_features.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one feature')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = _imageUrlController.text;

      // Upload image if selected
      if (_imageFile != null) {
        String carId = widget.car?.id ?? const Uuid().v4();
        imageUrl = await _carService.uploadCarImage(_imageFile!, carId);
      }

      CarModel car = CarModel(
        id: widget.car?.id ?? '',
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text),
        category: _selectedCategory,
        pricePerDay: double.parse(_priceController.text),
        imageUrl: imageUrl,
        features: _features,
        seatingCapacity: _seatingCapacity,
        fuelType: _selectedFuelType,
        transmission: _selectedTransmission,
        location: _locationController.text.trim(),
        rating: widget.car?.rating ?? 0.0,
        totalReviews: widget.car?.totalReviews ?? 0,
        createdAt: widget.car?.createdAt ?? DateTime.now(),
      );

      if (widget.car == null) {
        // Add new car
        await _carService.addCar(car);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Car added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Update existing car
        await _carService.updateCar(widget.car!.id, car.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Car updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.car == null ? 'Add Car' : 'Edit Car')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : (_imageUrlController.text.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _imageUrlController.text,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImagePlaceholder();
                                },
                              ),
                            )
                          : _buildImagePlaceholder()),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Car Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Brand and Model
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Year and Price
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price per Day (₹)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
            const SizedBox(height: 16),

            // Fuel Type and Transmission
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFuelType,
                    decoration: const InputDecoration(
                      labelText: 'Fuel Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _fuelTypes
                        .map(
                          (fuel) =>
                              DropdownMenuItem(value: fuel, child: Text(fuel)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedFuelType = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTransmission,
                    decoration: const InputDecoration(
                      labelText: 'Transmission',
                      border: OutlineInputBorder(),
                    ),
                    items: _transmissions
                        .map(
                          (trans) => DropdownMenuItem(
                            value: trans,
                            child: Text(trans),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedTransmission = value!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Seating Capacity
            Row(
              children: [
                const Text('Seating Capacity: '),
                Expanded(
                  child: Slider(
                    value: _seatingCapacity.toDouble(),
                    min: 2,
                    max: 8,
                    divisions: 6,
                    label: _seatingCapacity.toString(),
                    onChanged: (value) {
                      setState(() => _seatingCapacity = value.toInt());
                    },
                  ),
                ),
                Text(
                  '$_seatingCapacity Seats',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Image URL (optional if image is selected)
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Features
            const Text(
              'Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _featureController,
                    decoration: const InputDecoration(
                      hintText: 'Add feature',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addFeature,
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _features.asMap().entries.map((entry) {
                return Chip(
                  label: Text(entry.value),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeFeature(entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
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
          onPressed: _isLoading ? null : _saveCar,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.car == null ? 'Add Car' : 'Update Car',
                  style: const TextStyle(fontSize: 18),
                ),
        ),
      ),
    );
  }

  /// Build image placeholder
  Widget _buildImagePlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey),
        SizedBox(height: 8),
        Text('Tap to add image', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}

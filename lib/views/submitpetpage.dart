import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:pawpal/myconfig.dart';
import 'package:pawpal/models/user.dart';
import 'package:pawpal/views/mainpage.dart';

class SubmitPetPage extends StatefulWidget {
  final User? user;
  const SubmitPetPage({super.key, this.user});

  @override
  State<SubmitPetPage> createState() => _SubmitPetPageState();
}

class _SubmitPetPageState extends State<SubmitPetPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  String? _selectedPetType;
  String? _selectedCategory;
  double? _latitude;
  double? _longitude;
  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  bool _isGettingLocation = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Pet type options
  final List<String> _petTypes = ['Cat', 'Dog', 'Rabbit', 'Other'];
  
  // Submission category options
  final List<String> _categories = [
    'Adoption',
    'Donation Request',
    'Help/Rescue'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Build a readable address string
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }
        
        String address = addressParts.isNotEmpty 
            ? addressParts.join(', ')
            : '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
        
        setState(() {
          _locationController.text = address;
        });
      }
    } catch (e) {
      // If reverse geocoding fails, just show coordinates
      setState(() {
        _locationController.text = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable in settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Perform reverse geocoding to get address
      await _getAddressFromCoordinates(position.latitude, position.longitude);

      setState(() {
        _isGettingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // Prevents selecting more than 3 images
  Future<void> _pickImage() async { 
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) { // Form validation: triggers all validators
      return;
    }

    // Validate images: prevents submitting form without images
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate location coordinates (required)
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for location coordinates to be retrieved'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert images to base64
      List<String> base64Images = [];
      for (XFile image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        base64Images.add(base64String);
      }

      // Prepare JSON data
      Map<String, dynamic> requestData = {
        'user_id': widget.user?.userId ?? '',
        'pet_name': _petNameController.text.trim(),
        'pet_type': _selectedPetType,
        'submission_category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'latitude': _latitude.toString(),
        'longitude': _longitude.toString(),
        'images': base64Images,
      };
      

      // Make POST request
      var response = await http.post(
        Uri.parse("${MyConfig().baseUrl}/pawpal/api/submit_pet.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print("=== SUBMIT PET RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("=====================");

      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['success'] == true || jsondata['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(jsondata['message'] ?? 'Pet submitted successfully!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            
            // Clear form
            _petNameController.clear();
            _descriptionController.clear();
            setState(() {
              _selectedPetType = null;
              _selectedCategory = null;
              _selectedImages.clear();
            });
            
            // Navigate to main page after a short delay to ensure database is updated
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainPage(user: widget.user),
                  ),
                );
              }
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(jsondata['message'] ?? 'Failed to submit pet!'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error connecting to server!'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Pet'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pet Name Field
                  TextFormField(
                    controller: _petNameController,
                    decoration: const InputDecoration(
                      labelText: 'Pet Name *',
                      hintText: 'Enter pet name',
                      prefixIcon: Icon(Icons.pets),
                    ),
                    validator: (value) { // Pet Name: validates not empty
                      if (value == null || value.isEmpty) {
                        return 'Please enter pet name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Pet Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedPetType,
                    decoration: const InputDecoration(
                      labelText: 'Pet Type *',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _petTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPetType = newValue;
                      });
                    },
                    validator: (value) { // Pet Type: validates selection
                      if (value == null || value.isEmpty) {
                        return 'Please select pet type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Submission Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Submission Category *',
                      prefixIcon: Icon(Icons.label),
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                    validator: (value) { // Submission Category: validates selection
                      if (value == null || value.isEmpty) {
                        return 'Please select submission category';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Enter description (minimum 10 characters)',
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (value) { // Description: validates not empty and minimum 10 characters
                      if (value == null || value.isEmpty) {
                        return 'Please enter description';
                      }
                      if (value.trim().length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Location Field
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: 'Location *',
                            hintText: 'Address will be auto-filled',
                            prefixIcon: const Icon(Icons.location_on),
                            suffixIcon: _isGettingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _getCurrentLocation,
                                    tooltip: 'Refresh location',
                                  ),
                          ),
                          readOnly: false,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please wait for location to be retrieved';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Display coordinates below the address field
                  if (_latitude != null && _longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'Coordinates: Lat ${_latitude!.toStringAsFixed(6)}, Lng ${_longitude!.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Image Upload Section
                  const Text(
                    'Pet Images * (1-3 images)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Image Preview Grid
                  if (_selectedImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF1493),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Add Image Button
                  if (_selectedImages.length < 3)
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text('Add Image (${_selectedImages.length}/3)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isGettingLocation) ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit Pet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
}


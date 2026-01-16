/**
 * Submit Pet Page
 * 
 * This screen allows users to submit a new pet entry with the following information:
 * - Pet name, type, category (required)
 * - Age, gender, health status (required)
 * - Description (required, minimum 10 characters)
 * - Location (automatically retrieved via GPS)
 * - Images (1-3 images, required)
 * 
 * Features:
 * - Automatic location retrieval using GPS
 * - Reverse geocoding to display readable address
 * - Image picker for selecting pet photos
 * - Form validation for all required fields
 * - Base64 encoding of images for API transmission
 * - Error handling with user-friendly messages
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:pawpal/myconfig.dart';
import 'package:pawpal/models/user.dart';
import 'package:pawpal/views/mainpage.dart';

class SubmitPetPage extends StatefulWidget {
  final User? user;  // Current logged-in user (for associating pet with user)
  const SubmitPetPage({super.key, this.user});

  @override
  State<SubmitPetPage> createState() => _SubmitPetPageState();
}

class _SubmitPetPageState extends State<SubmitPetPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _healthController = TextEditingController();
  
  String? _selectedPetType;
  String? _selectedCategory;
  String? _selectedGender;
  double? _latitude;
  double? _longitude;
  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isEncodingImages = false;
  int _encodingProgress = 0;
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
    // Delay location retrieval to allow UI to render first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _healthController.dispose();
    super.dispose();
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      print("=== REVERSE GEOCODING ===");
      print("Looking up address for: $latitude, $longitude");
      
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Debug: Log placemark details
        print("Country: ${place.country}");
        print("Administrative Area: ${place.administrativeArea}");
        print("Locality: ${place.locality}");
        print("Street: ${place.street}");
        print("======================");
        
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
        
        print("Final address: $address");
        
        setState(() {
          _locationController.text = address;
        });
      } else {
        print("No placemarks found, using coordinates");
        setState(() {
          _locationController.text = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
        });
      }
    } catch (e) {
      print("Reverse geocoding error: $e");
      // If reverse geocoding fails, just show coordinates
      setState(() {
        _locationController.text = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
      });
    }
  }

  /**
   * Get Current Location
   * 
   * Retrieves the device's current GPS coordinates and converts them to a readable address.
   * 
   * Process:
   * 1. Check if location services are enabled
   * 2. Request location permissions if needed
   * 3. Get current position with high accuracy
   * 4. Validate coordinates (not 0,0)
   * 5. Reverse geocode coordinates to get address
   * 6. Display address in location field
   * 
   * Error Handling:
   * - Location services disabled → Shows message to enable in settings
   * - Permissions denied → Shows message to grant permissions
   * - Timeout → Shows message to try again
   * - Invalid coordinates → Shows error message
   */
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;  // Show loading indicator
    });

    try {
      // Step 1: Check if location services (GPS) are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them in device settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
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
                content: Text('Location permissions are denied. Please grant location permission to use this feature.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
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
              content: Text('Location permissions are permanently denied. Please enable in app settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position with timeout and better error handling
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15), // 15 second timeout
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Location request timed out. Please try again.');
        },
      );

      // Validate coordinates
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        throw Exception('Invalid location coordinates received.');
      }

      // Debug: Log coordinates to verify location
      print("=== LOCATION DEBUG ===");
      print("Latitude: ${position.latitude}");
      print("Longitude: ${position.longitude}");
      print("Accuracy: ${position.accuracy} meters");
      print("=====================");

      // Check if coordinates look like default/test location (Google HQ)
      // Google HQ: 37.421998, -122.084000
      if ((position.latitude >= 37.4 && position.latitude <= 37.5) && 
          (position.longitude >= -122.1 && position.longitude <= -122.0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Location appears to be a default/test location. If using an emulator, please set a custom location in emulator settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Perform reverse geocoding to get address
      await _getAddressFromCoordinates(position.latitude, position.longitude);

      setState(() {
        _isGettingLocation = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location retrieved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.message} Make sure GPS is enabled and try again.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _isGettingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error getting location: ';
        if (e.toString().contains('PERMISSION_DENIED')) {
          errorMessage += 'Location permission denied. Please grant permission in settings.';
        } else if (e.toString().contains('LOCATION_SERVICES_DISABLED')) {
          errorMessage += 'Location services are disabled. Please enable GPS.';
        } else {
          errorMessage += e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
      _isEncodingImages = true;
      _encodingProgress = 0;
    });

    try {
      // Convert images to base64 in isolate to prevent UI blocking
      List<String> base64Images = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        
        // Update progress
        setState(() {
          _encodingProgress = i + 1;
        });
        
        // Read bytes asynchronously
        final bytes = await image.readAsBytes();
        
        // Encode to base64 in isolate to prevent UI blocking
        // Use compute for images, but fallback if it fails or is too large
        String base64String;
        // Isolate message size limit is typically 2MB, so use compute for smaller images
        if (bytes.length < 1500000) { // ~1.5MB to be safe
          try {
            base64String = await compute(_encodeToBase64, bytes);
          } catch (e) {
            // Fallback to direct encoding if compute fails
            print("Compute failed, using direct encoding: $e");
            // Use microtask to yield control to UI
            await Future.microtask(() {});
            base64String = base64Encode(bytes);
          }
        } else {
          // For very large images, encode directly but yield to UI periodically
          print("Large image detected (${bytes.length} bytes), encoding directly with yields");
          await Future.microtask(() {}); // Yield to UI before encoding
          base64String = base64Encode(bytes);
        }
        base64Images.add(base64String);
        
        // Allow UI to update between images
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      setState(() {
        _isEncodingImages = false;
      });

      // Get user name for posted_by_name
      String? postedByName = widget.user?.name;
      
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
        'age': _ageController.text.trim(),
        'gender': _selectedGender,
        'health': _healthController.text.trim(),
        'posted_by_name': postedByName,
      };
      
      // Encode JSON - estimate size first to decide encoding strategy
      String jsonBody;
      try {
        // Estimate payload size by summing base64 image sizes
        int estimatedSize = 0;
        for (String img in base64Images) {
          estimatedSize += img.length;
        }
        // Add estimated size for other fields (~500 bytes)
        estimatedSize += 500;
        
        // Only use compute for very large payloads (>2MB to avoid isolate message limits)
        if (estimatedSize > 2000000) {
          try {
            jsonBody = await compute(_encodeJson, requestData);
          } catch (e) {
            print("JSON encoding in isolate failed, using direct: $e");
            // Yield to UI before direct encoding
            await Future.microtask(() {});
            jsonBody = jsonEncode(requestData);
          }
        } else {
          // For smaller payloads, direct encoding is fast enough
          jsonBody = jsonEncode(requestData);
        }
      } catch (e) {
        // Fallback to direct encoding
        print("JSON encoding error: $e");
        jsonBody = jsonEncode(requestData);
      }

      // Make POST request with timeout to prevent hanging
      var response = await http.post(
        Uri.parse("${MyConfig().baseUrl}/pawpal/api/submit_pet.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      ).timeout(
        const Duration(seconds: 60), // Increased timeout for large image uploads
        onTimeout: () {
          throw TimeoutException('Request timed out. Please check your connection and try again.');
        },
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
            _ageController.clear();
            _healthController.clear();
            setState(() {
              _selectedPetType = null;
              _selectedCategory = null;
              _selectedGender = null;
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
          _isEncodingImages = false;
          _encodingProgress = 0;
        });
      }
    }
  }

  // Helper function to encode bytes to base64 in isolate
  static String _encodeToBase64(List<int> bytes) {
    return base64Encode(bytes);
  }
  
  // Helper function to encode JSON in isolate for large payloads
  static String _encodeJson(Map<String, dynamic> data) {
    return jsonEncode(data);
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

                  // Age Field
                  TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Age *',
                      hintText: 'e.g., 2 years, 6 months, Puppy',
                      prefixIcon: Icon(Icons.cake),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter pet age';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender *',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: ['Male', 'Female', 'Unknown']
                        .map((String gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select gender';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Health Status Field
                  TextFormField(
                    controller: _healthController,
                    decoration: const InputDecoration(
                      labelText: 'Health Status *',
                      hintText: 'e.g., Healthy, Needs medical attention, Recovering',
                      prefixIcon: Icon(Icons.health_and_safety),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter health status';
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
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                if (_isEncodingImages && _selectedImages.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12.0),
                                    child: Text(
                                      'Encoding images ($_encodingProgress/${_selectedImages.length})...',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
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


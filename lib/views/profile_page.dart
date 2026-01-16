/**
 * Profile Page
 * 
 * This screen displays and allows editing of user profile information.
 * 
 * Features:
 * - Display current user data (name, email, phone, profile image)
 * - Edit mode to update name, phone, and profile image
 * - Image picker for selecting new profile photo
 * - Profile image upload to server filesystem
 * - Session management using SharedPreferences
 * - Auto-refresh user data from server on load
 * 
 * Profile Image Handling:
 * - Images saved to server/pawpal/api/uploads/ directory
 * - Filename format: profile_{user_id}_{timestamp}_{random}.jpg
 * - Old images are deleted when new one is uploaded
 * - Images displayed from server URL or local file
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pawpal/myconfig.dart';
import 'package:pawpal/models/user.dart';
import 'package:pawpal/views/loginpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final User? currentUser;  // Current logged-in user object
  
  const ProfilePage({super.key, this.currentUser});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _currentUser;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSaving = false;
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _loadUserData();
    // Refresh user data from server to get latest profile image
    _refreshUserData();
  }

  /**
   * Refresh User Data from Server
   * 
   * Fetches the latest user data from the server to ensure profile image
   * and other fields are up-to-date. This is called on page initialization.
   * 
   * Process:
   * 1. Make GET request to get_user_profile.php API
   * 2. Parse JSON response
   * 3. Update local user object
   * 4. Update SharedPreferences with fresh data
   * 5. Reload UI to display updated information
   * 
   * Fallback: If server request fails, loads from SharedPreferences
   */
  Future<void> _refreshUserData() async {
    if (_currentUser == null || _currentUser!.userId == null) return;
    
    try {
      String baseUrl = MyConfig().baseUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      // Get fresh user data from server to ensure profile image is current
      String url = "$baseUrl/pawpal/api/get_user_profile.php?user_id=${_currentUser!.userId}";
      var response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['status'] == 'success' && jsondata['data'] != null) {
          setState(() {
            _currentUser = User.fromJson(jsondata['data']);
            _loadUserData();
          });
          
          // Update SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
        }
      }
    } catch (e) {
      print("Error refreshing user data: $e");
      // Fallback to SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userDataJson = prefs.getString('user_data');
      if (userDataJson != null) {
        try {
          Map<String, dynamic> userData = jsonDecode(userDataJson);
          setState(() {
            _currentUser = User.fromJson(userData);
            _loadUserData();
          });
        } catch (e) {
          print("Error loading from SharedPreferences: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    if (_currentUser != null) {
      _nameController.text = _currentUser!.userName ?? '';
      _emailController.text = _currentUser!.userEmail ?? '';
      _phoneController.text = _currentUser!.userPhone ?? '';
      
      // Load profile image URL if exists
      if (_currentUser!.profileImage != null && _currentUser!.profileImage!.isNotEmpty) {
        String imagePath = _currentUser!.profileImage!;
        print("Loading profile image from path: $imagePath");
        if (!imagePath.startsWith('http')) {
          String baseUrl = MyConfig().baseUrl;
          if (baseUrl.endsWith('/')) {
            baseUrl = baseUrl.substring(0, baseUrl.length - 1);
          }
          // Construct full URL - image path is relative to api directory
          _profileImageUrl = "$baseUrl/pawpal/api/$imagePath";
          print("Constructed profile image URL: $_profileImageUrl");
        } else {
          _profileImageUrl = imagePath;
        }
      } else {
        _profileImageUrl = null;
        print("No profile image path in user data");
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /**
   * Upload Profile Image
   * 
   * Converts the selected image file to base64 encoding for transmission to the API.
   * 
   * Process:
   * 1. Read image file as bytes
   * 2. Encode bytes to base64 string
   * 3. Return base64 string for API transmission
   * 
   * Note: The API (update_user_profile.php) will:
   * - Decode base64 to binary
   * - Save to server filesystem (uploads/ directory)
   * - Store file path in database
   * 
   * @return Base64-encoded image string, or null if error
   */
  Future<String?> _uploadImage() async {
    if (_profileImage == null) return null;

    try {
      // Read image file as bytes
      List<int> imageBytes = await _profileImage!.readAsBytes();
      
      // Encode bytes to base64 string for API transmission
      // Base64 encoding allows binary image data to be sent as text in JSON
      String base64Image = base64Encode(imageBytes);
      
      // Note: Filename generation is handled by the API server
      // The API will create: profile_{user_id}_{timestamp}_{random}.jpg
      
      return base64Image;
    } catch (e) {
      print("Error encoding image: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String baseUrl = MyConfig().baseUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      String url = "$baseUrl/pawpal/api/update_user_profile.php";
      
      Map<String, dynamic> requestData = {
        'user_id': _currentUser!.userId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      // Upload image if selected
      if (_profileImage != null) {
        String? base64Image = await _uploadImage();
        if (base64Image != null) {
          // Send as data URL for API to process
          requestData['profile_image'] = 'data:image/jpeg;base64,$base64Image';
        }
      }

      var response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['status'] == 'success') {
          // Update local user data
          if (jsondata['data'] != null) {
            _currentUser = User.fromJson(jsondata['data']);
            // Ensure profile image is set correctly from response
            if (jsondata['data']['profile_image'] != null && jsondata['data']['profile_image'] != '') {
              _currentUser!.profileImage = jsondata['data']['profile_image'];
            }
            _loadUserData(); // Reload to update profile image URL
          } else {
            // Update manually
            _currentUser!.userName = _nameController.text.trim();
            _currentUser!.userPhone = _phoneController.text.trim();
          }
          
          /**
           * REQUIREMENT: Save user session using SharedPreferences
           * 
           * After successful profile update, save the updated user data to SharedPreferences.
           * This ensures:
           * - User session persists across app restarts
           * - Profile image path is saved locally
           * - User data is available immediately on next app launch
           * - No need to re-login if session is valid
           */
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
          
          // Force UI update to show new profile image
          if (mounted) {
            setState(() {
              _isEditing = false;
              _profileImage = null; // Clear selected image after save
              // Reload image URL to ensure it's updated
              if (_currentUser!.profileImage != null && _currentUser!.profileImage!.isNotEmpty) {
                String imagePath = _currentUser!.profileImage!;
                if (!imagePath.startsWith('http')) {
                  String baseUrl = MyConfig().baseUrl;
                  if (baseUrl.endsWith('/')) {
                    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
                  }
                  _profileImageUrl = "$baseUrl/pawpal/api/$imagePath";
                } else {
                  _profileImageUrl = imagePath;
                }
              }
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(jsondata['message'] ?? 'Failed to update profile'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please login to view profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _loadUserData(); // Reset to original values
                  _profileImage = null;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!) as ImageProvider
                            : null),
                    child: _profileImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 60)
                        : null,
                    // Only provide onBackgroundImageError when backgroundImage is not null
                    onBackgroundImageError: (_profileImage != null || (_profileImageUrl != null && _profileImageUrl!.isNotEmpty))
                        ? (exception, stackTrace) {
                            // Handle image loading error
                            print("Profile image load error: $exception");
                            print("Profile image URL: $_profileImageUrl");
                            print("Profile image path in DB: ${_currentUser?.profileImage}");
                            if (mounted) {
                              setState(() {
                                _profileImageUrl = null;
                              });
                            }
                          }
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                  filled: !_isEditing,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Email Field (read-only)
              TextFormField(
                controller: _emailController,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                  filled: !_isEditing,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Save Button (only when editing)
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

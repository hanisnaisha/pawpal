import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pawpal/myconfig.dart';
import 'package:pawpal/models/pet.dart';
import 'package:pawpal/models/user.dart';
import 'package:pawpal/views/donation_page.dart';

class PetDetailsPage extends StatefulWidget {
  final Pet pet;
  final User? currentUser;
  
  const PetDetailsPage({super.key, required this.pet, this.currentUser});

  @override
  State<PetDetailsPage> createState() => _PetDetailsPageState();
}

class _PetDetailsPageState extends State<PetDetailsPage> {
  Pet? _petDetails;
  bool _isLoading = true;
  bool _showAdoptionForm = false;
  final TextEditingController _motivationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _petDetails = widget.pet;
    _loadPetDetails();
  }

  @override
  void dispose() {
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _loadPetDetails() async {
    if (widget.pet.petId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      String baseUrl = MyConfig().baseUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      String url = "$baseUrl/pawpal/api/get_pet_details.php?pet_id=${widget.pet.petId}";
      
      var response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['status'] == 'success' && jsondata['data'] != null) {
          setState(() {
            _petDetails = Pet.fromJson(jsondata['data']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading pet details: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAdoptionRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.currentUser == null || widget.currentUser!.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to submit adoption request'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String baseUrl = MyConfig().baseUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      String url = "$baseUrl/pawpal/api/submit_adoption_request.php";
      
      var response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pet_id': widget.pet.petId,
          'user_id': widget.currentUser!.userId,
          'motivation_message': _motivationController.text.trim(),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Adoption request submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {
              _showAdoptionForm = false;
              _motivationController.clear();
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(jsondata['message'] ?? 'Failed to submit request'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pet Details'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_petDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pet Details'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Pet not found')),
      );
    }

    Pet pet = _petDetails!;
    String? imageUrl;
    if (pet.imagePaths != null && pet.imagePaths!.isNotEmpty) {
      String imagePath = pet.imagePaths!.first;
      if (!imagePath.startsWith('http')) {
        String baseUrl = MyConfig().baseUrl;
        if (baseUrl.endsWith('/')) {
          baseUrl = baseUrl.substring(0, baseUrl.length - 1);
        }
        imageUrl = "$baseUrl/pawpal/api/$imagePath";
      } else {
        imageUrl = imagePath;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet Image
            if (imageUrl != null)
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.pets, size: 100);
                  },
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet Name
                  Text(
                    pet.petName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Pet Info Grid
                  _buildInfoRow('Type', pet.petType ?? 'Unknown', Icons.pets),
                  if (pet.age != null) _buildInfoRow('Age', pet.age!, Icons.cake),
                  if (pet.gender != null) _buildInfoRow('Gender', pet.gender!, Icons.wc),
                  if (pet.health != null) _buildInfoRow('Health', pet.health!, Icons.health_and_safety),
                  _buildInfoRow('Category', pet.submissionCategory ?? 'Unknown', Icons.category),
                  if (pet.postedByName != null)
                    _buildInfoRow('Posted by', pet.postedByName!, Icons.person),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pet.description ?? 'No description available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Donation Button (if pet needs help)
                  if (pet.needsHelp == true && widget.currentUser != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DonationPage(
                                pet: pet,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ).then((success) {
                            if (success == true) {
                              // Refresh if donation was successful
                            }
                          });
                        },
                        icon: const Icon(Icons.card_giftcard),
                        label: const Text('Make a Donation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  
                  if (pet.needsHelp == true && widget.currentUser != null)
                    const SizedBox(height: 16),
                  
                  // Adoption Request Button
                  if (!_showAdoptionForm && widget.currentUser != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAdoptionForm = true;
                          });
                        },
                        icon: const Icon(Icons.favorite),
                        label: const Text('Request to Adopt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  
                  // Adoption Form
                  if (_showAdoptionForm)
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adoption Request',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _motivationController,
                            decoration: const InputDecoration(
                              labelText: 'Motivation Message',
                              hintText: 'Why do you want to adopt this pet?',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 5,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a motivation message';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAdoptionForm = false;
                                      _motivationController.clear();
                                    });
                                  },
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _submitAdoptionRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Submit Request'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

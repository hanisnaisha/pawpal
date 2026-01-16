import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pawpal/myconfig.dart';
import 'package:pawpal/models/pet.dart';
import 'package:pawpal/models/user.dart';
import 'package:pawpal/views/pet_details_page.dart';

class PublicPetsPage extends StatefulWidget {
  final User? currentUser;
  
  const PublicPetsPage({super.key, this.currentUser});

  @override
  State<PublicPetsPage> createState() => _PublicPetsPageState();
}

class _PublicPetsPageState extends State<PublicPetsPage> {
  List<Pet> _allPets = [];
  List<Pet> _filteredPets = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedPetType = 'All';

  @override
  void initState() {
    super.initState();
    _loadPets();
    _searchController.addListener(_filterPets);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String baseUrl = MyConfig().baseUrl;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      
      String url = "$baseUrl/pawpal/api/get_all_pets.php";
      
      var response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['status'] == 'success' && jsondata['data'] != null) {
          List<dynamic> petsData = jsondata['data'];
          setState(() {
            _allPets = petsData.map((json) => Pet.fromJson(json)).toList();
            _filteredPets = _allPets;
            _isLoading = false;
          });
        } else {
          setState(() {
            _allPets = [];
            _filteredPets = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _allPets = [];
          _filteredPets = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading pets: $e");
      setState(() {
        _allPets = [];
        _filteredPets = [];
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pets: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterPets() {
    String searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredPets = _allPets.where((pet) {
        bool matchesSearch = searchQuery.isEmpty || 
            (pet.petName?.toLowerCase().contains(searchQuery) ?? false);
        bool matchesType = _selectedPetType == 'All' || 
            pet.petType == _selectedPetType;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void _onPetTypeChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedPetType = value;
      });
      _filterPets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Pets'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by pet name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedPetType,
                  decoration: InputDecoration(
                    labelText: 'Filter by Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items: ['All', 'Cat', 'Dog', 'Rabbit', 'Other']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: _onPetTypeChanged,
                ),
              ],
            ),
          ),
          // Pets List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No pets found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPets,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPets.length,
                          itemBuilder: (context, index) {
                            return _buildPetCard(_filteredPets[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Pet pet) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetDetailsPage(
                pet: pet,
                currentUser: widget.currentUser,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.pets, size: 50),
                          );
                        },
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.pets, size: 50),
                      ),
              ),
              const SizedBox(width: 12),
              // Pet Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.petName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          pet.petType ?? 'Unknown',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (pet.age != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            pet.age!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    if (pet.health != null && pet.health!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.health_and_safety, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              pet.health!,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (pet.postedByName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Posted by: ${pet.postedByName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

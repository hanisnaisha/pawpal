import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pawpal/models/user.dart';
import 'package:pawpal/models/pet.dart';
import 'package:pawpal/views/loginpage.dart';
import 'package:pawpal/views/submitpetpage.dart';
import 'package:pawpal/myconfig.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainPage extends StatefulWidget {
  final User? user;
  const MainPage({super.key, this.user});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  User? _currentUser;
  List<Pet> _pets = [];
  List<Pet> _filteredPets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _filterScrollController = ScrollController();

  // Pet type filters
  final List<String> _petTypeFilters = ['All', 'Cat', 'Dog', 'Rabbit', 'Others'];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadPets();
  }


  @override
  void dispose() {
    _searchController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch pets for the logged-in user only
      String userId = _currentUser?.userId ?? '';
      var response = await http.get(
        Uri.parse("${MyConfig().baseUrl}/pawpal/api/get_my_pets.php?user_id=$userId"),
      );

      print("=== GET PETS RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");
      print("=====================");

      if (response.statusCode == 200) {
        var jsondata = jsonDecode(response.body);
        if (jsondata['status'] == 'success' && jsondata['data'] != null) {
          List<dynamic> petsData = jsondata['data'];
          setState(() {
            _pets = petsData.map((json) => Pet.fromJson(json)).toList();
            _filteredPets = _pets;
            _isLoading = false;
          });
        } else {
          setState(() {
            _pets = [];
            _filteredPets = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _pets = [];
          _filteredPets = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading pets: $e");
      setState(() {
        _pets = [];
        _filteredPets = [];
        _isLoading = false;
      });
    }
  }

  void _filterPets() {
    setState(() {
      _filteredPets = _pets.where((pet) {
        // Filter by pet type
        bool matchesType = false;
        if (_selectedFilter == 'All') {
          matchesType = true;
        } else if (_selectedFilter == 'Others') {
          // "Others" filter should match "Other" pet type
          matchesType = pet.petType == 'Other' || pet.petType == 'Others';
        } else {
          matchesType = pet.petType == _selectedFilter;
        }
        
        // Filter by search query
        bool matchesSearch = _searchQuery.isEmpty ||
            (pet.petName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (pet.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        return matchesType && matchesSearch;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterPets();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterPets();
  }

  Future<void> _logout() async {
    // Clear remember me data
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    await prefs.remove('rememberme');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _navigateToAddPet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitPetPage(user: _currentUser),
      ),
    ).then((_) {
      // Refresh pets list when returning from submit page
      _loadPets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Search Bar and Filter
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1493), 
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () {
                        // Filter functionality is handled by filter buttons below
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Filter Buttons - Horizontal Scrollable with Arrow Controls
            Row(
              children: [
                // Left Arrow Button
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    _filterScrollController.animateTo(
                      _filterScrollController.offset - 100,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  color: Colors.black,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                // Filter Buttons List
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ListView.builder(
                      controller: _filterScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _petTypeFilters.length,
                      itemBuilder: (context, index) {
                        String filter = _petTypeFilters[index];
                        bool isSelected = _selectedFilter == filter;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: FilterChip(
                            selected: isSelected,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (filter == 'All')
                                  Icon(
                                    Icons.pets,
                                    size: 16,
                                    color: isSelected ? Colors.white : const Color(0xFFFF1493), // Hot Pink
                                  )
                                else if (filter == 'Dog' || filter == 'Cat' || filter == 'Rabbit')
                                  Icon(
                                    Icons.pets,
                                    size: 16,
                                    color: isSelected ? Colors.white : Colors.grey.shade700,
                                  ),
                                if (filter == 'All' || filter == 'Dog' || filter == 'Cat' || filter == 'Rabbit')
                                  const SizedBox(width: 4),
                                Text(
                                  filter,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            onSelected: (selected) {
                              _onFilterChanged(filter);
                            },
                            selectedColor: const Color(0xFFFF1493), // Hot Pink / Shocking Pink
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Right Arrow Button
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    _filterScrollController.animateTo(
                      _filterScrollController.offset + 100,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  color: Colors.black,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Pets List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : _filteredPets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pets,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _pets.isEmpty
                                    ? 'No submissions yet.'
                                    : 'No pets match your search',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPets,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredPets.length,
                            itemBuilder: (context, index) {
                              return _buildPetCard(_filteredPets[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0, // Home is always selected
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              label: 'Add Pet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout),
              label: 'Logout',
            ),
          ],
          onTap: (index) {
            if (index == 1) {
              _navigateToAddPet();
            } else if (index == 2) {
              _logout();
            }
            // Index 0 (Home) does nothing as we're already on home
          },
        ),
      ),
    );
  }

  Widget _buildPetCard(Pet pet) {
    String? imageUrl;
    if (pet.imagePaths != null && pet.imagePaths!.isNotEmpty) {
      // Construct full image URL from backend
      String imagePath = pet.imagePaths!.first;
      if (!imagePath.startsWith('http')) {
        // Images are stored in api/uploads/ directory
        imageUrl = "${MyConfig().baseUrl}/pawpal/api/$imagePath";
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
          // TODO: Navigate to pet details page
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
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.pets,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.pets,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              
              // Pet Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pet.petName ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite_border),
                          color: Colors.grey,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            // TODO: Add to favorites
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Pet Type
                    Text(
                      pet.petType ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Category
                    Text(
                      pet.submissionCategory ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description excerpt (first 100 characters)
                    if (pet.description != null && pet.description!.isNotEmpty)
                      Text(
                        pet.description!.length > 100
                            ? '${pet.description!.substring(0, 100)}...'
                            : pet.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

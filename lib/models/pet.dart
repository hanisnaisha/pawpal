class Pet {
  String? petId;
  String? userId;
  String? petName;
  String? petType;
  String? submissionCategory;
  String? description;
  double? latitude;
  double? longitude;
  String? submissionDate;
  List<String>? imagePaths;

  Pet({
    this.petId,
    this.userId,
    this.petName,
    this.petType,
    this.submissionCategory,
    this.description,
    this.latitude,
    this.longitude,
    this.submissionDate,
    this.imagePaths,
  });

  Pet.fromJson(Map<String, dynamic> json) {
    petId = json['pet_id']?.toString() ?? json['id']?.toString();
    userId = json['user_id']?.toString();
    petName = json['pet_name'] ?? json['name'];
    petType = json['pet_type'] ?? json['type'];
    submissionCategory = json['submission_category'] ?? json['category'];
    description = json['description'];
    latitude = json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null;
    longitude = json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null;
    submissionDate = json['submission_date'] ?? json['date'];
    
    // Handle image paths - could be a string or array
    if (json['image_paths'] != null) {
      if (json['image_paths'] is List) {
        imagePaths = List<String>.from(json['image_paths']);
      } else if (json['image_paths'] is String) {
        imagePaths = [json['image_paths']];
      }
    } else if (json['image_path'] != null) {
      imagePaths = [json['image_path']];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['pet_id'] = petId;
    data['user_id'] = userId;
    data['pet_name'] = petName;
    data['pet_type'] = petType;
    data['submission_category'] = submissionCategory;
    data['description'] = description;
    data['latitude'] = latitude?.toString();
    data['longitude'] = longitude?.toString();
    data['submission_date'] = submissionDate;
    data['image_paths'] = imagePaths;
    return data;
  }
}


# PawPal - Pet Adoption & Donation Platform

A Flutter mobile application for pet submissions, adoptions, and donations with a PHP backend API. Users can register, login, submit pet information with images and location data, view public pet listings, request adoptions, make donations, and manage their profile.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Database Setup](#database-setup)
- [API Documentation](#api-documentation)
- [Flutter App Configuration](#flutter-app-configuration)
- [Troubleshooting](#troubleshooting)
- [Code Comments](#code-comments)

## Features

### Core Features
- **User Authentication**: Registration and login with session management
- **Pet Submission**: Submit pets with images, location, age, gender, and health status
- **Public Pet Listing**: Browse all pets with search and filter functionality
- **Pet Details**: View detailed pet information
- **Adoption Requests**: Submit adoption requests with motivation messages
- **Donation System**: Make donations (Food, Medical, Money) for pets needing help
- **User Profile**: View and edit profile with image upload
- **My Pets**: View pets submitted by logged-in user
- **My Donations**: View donation history

### Technical Features
- Image upload and storage on server
- Location services with GPS coordinates
- Session management using SharedPreferences
- Form validation
- Error handling and timeout management
- CORS-enabled RESTful APIs

## Project Structure

```
pawpal/
├── lib/
│   ├── models/           # Data models (User, Pet)
│   ├── views/            # Flutter UI screens
│   │   ├── loginpage.dart
│   │   ├── registerpage.dart
│   │   ├── mainpage.dart
│   │   ├── submitpetpage.dart
│   │   ├── public_pets_page.dart
│   │   ├── pet_details_page.dart
│   │   ├── donation_page.dart
│   │   ├── my_donations_page.dart
│   │   └── profile_page.dart
│   └── myconfig.dart     # API base URL configuration
├── server/
│   └── pawpal/
│       └── api/          # PHP API endpoints
│           ├── dbconnect.php
│           ├── register_user.php
│           ├── login_user.php
│           ├── submit_pet.php
│           ├── get_my_pets.php
│           ├── get_all_pets.php
│           ├── get_pet_details.php
│           ├── submit_adoption_request.php
│           ├── submit_donation.php
│           ├── get_my_donations.php
│           ├── update_user_profile.php
│           └── get_user_profile.php
└── android/              # Android-specific configuration
```

## Setup Instructions

### Prerequisites

- **Flutter SDK** (3.9.2 or higher)
- **PHP** 7.4 or higher
- **MySQL/MariaDB** database
- **Web server** (Apache/Nginx) with PHP support
- **Android Studio** / Xcode (for mobile development)
- **Java JDK** 11 or higher (for Android builds)

### Backend Setup

1. **Copy Server Files**
   - Copy the `server/pawpal` directory to your web server's document root
   - For XAMPP: `C:\xampp\htdocs\pawpal\`
   - Ensure the `api/uploads/` directory exists and has write permissions (chmod 755)

2. **Database Configuration**
   - Update database credentials in `server/pawpal/api/dbconnect.php`:
     ```php
     $servername = "localhost";
     $username = "root";
     $password = "";
     $dbname = "pawpal_db";
     ```

3. **Run Database Setup** (see [Database Setup](#database-setup) section below)

### Flutter App Setup

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure Base URL**
   - Update `lib/myconfig.dart` with your server's IP address:
     ```dart
     String baseUrl = "http://10.0.2.2";  // For Android Emulator
     // OR
     String baseUrl = "http://YOUR_COMPUTER_IP";  // For Physical Device
     ```
   - **Android Emulator**: Use `http://10.0.2.2` (maps to localhost)
   - **Physical Device**: Use your computer's IPv4 address (e.g., `http://10.29.194.155`)

3. **Run the Application**
   ```bash
   flutter run
   ```

### Permissions

The app requires the following permissions (configured in `android/app/src/main/AndroidManifest.xml`):
- **Location**: For capturing pet location coordinates
- **Camera/Gallery**: For selecting pet images
- **Internet**: For API communication

## Database Setup

### Initial Database Creation

Run this SQL script in phpMyAdmin or MySQL command line:

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS pawpal_db;
USE pawpal_db;

-- Create tbl_users table
CREATE TABLE IF NOT EXISTS tbl_users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    profile_image VARCHAR(255) DEFAULT NULL,
    reg_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create tbl_pets table
CREATE TABLE IF NOT EXISTS tbl_pets (
    pet_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    posted_by_name VARCHAR(255) DEFAULT NULL,
    pet_name VARCHAR(255) NOT NULL,
    pet_type VARCHAR(50) NOT NULL,
    age VARCHAR(50) DEFAULT NULL,
    gender VARCHAR(20) DEFAULT NULL,
    health VARCHAR(255) DEFAULT NULL,
    needs_help TINYINT(1) DEFAULT 0,
    submission_category VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    image_paths TEXT,
    submission_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_pet_type (pet_type),
    INDEX idx_submission_category (submission_category),
    FOREIGN KEY (user_id) REFERENCES tbl_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create tbl_adoptions table
CREATE TABLE IF NOT EXISTS tbl_adoptions (
    adoption_id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    user_id INT NOT NULL,
    motivation_message TEXT NOT NULL,
    request_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    INDEX idx_pet_id (pet_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    FOREIGN KEY (pet_id) REFERENCES tbl_pets(pet_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES tbl_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create tbl_donations table
CREATE TABLE IF NOT EXISTS tbl_donations (
    donation_id INT AUTO_INCREMENT PRIMARY KEY,
    pet_id INT NOT NULL,
    user_id INT NOT NULL,
    donation_type VARCHAR(50) NOT NULL,
    amount DECIMAL(10, 2) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    donation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pet_id (pet_id),
    INDEX idx_user_id (user_id),
    INDEX idx_donation_type (donation_type),
    FOREIGN KEY (pet_id) REFERENCES tbl_pets(pet_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES tbl_users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Database Notes

- **Foreign Keys**: All foreign keys use `ON DELETE CASCADE` to automatically delete related records
- **ID Gaps**: User and Pet IDs may have gaps (e.g., 1, 2, 3, 5, 6) - this is normal MySQL behavior
- **Character Encoding**: All tables use `utf8mb4` for proper Unicode support

## API Documentation

### Base URL
```
http://YOUR_SERVER_IP/pawpal/api/
```

### Authentication APIs

#### 1. User Registration
**Endpoint:** `POST /register_user.php`

**Request Parameters:**
- `name` (string, required) - User's full name
- `email` (string, required) - Valid email address
- `password` (string, required) - Password (hashed with SHA1)
- `phone` (string, required) - Phone number

**Response:**
```json
{
  "status": "success",
  "message": "User registered successfully"
}
```

#### 2. User Login
**Endpoint:** `POST /login_user.php`

**Request Parameters:**
- `email` (string, required)
- `password` (string, required)

**Response:**
```json
{
  "status": "success",
  "message": "Login successful",
  "data": {
    "user_id": "1",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "1234567890",
    "profile_image": "uploads/profile_1_123456.jpg"
  }
}
```

### Pet APIs

#### 3. Submit Pet
**Endpoint:** `POST /submit_pet.php`

**Request Body (JSON):**
```json
{
  "user_id": "1",
  "pet_name": "Fluffy",
  "pet_type": "Cat",
  "submission_category": "Adoption",
  "age": "2 years",
  "gender": "Male",
  "health": "Healthy",
  "description": "Friendly orange tabby cat",
  "latitude": "3.1390",
  "longitude": "101.6869",
  "images": ["base64_image_1", "base64_image_2"]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Pet submitted successfully"
}
```

**Notes:**
- Maximum 3 images per submission
- Description must be at least 10 characters
- Images are saved to `api/uploads/` directory
- `needs_help` is automatically set to 1 if category is "Donation Request" or "Help/Rescue"

#### 4. Get All Pets (Public Listing)
**Endpoint:** `GET /get_all_pets.php`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "pet_id": "1",
      "pet_name": "Fluffy",
      "pet_type": "Cat",
      "age": "2 years",
      "health": "Healthy",
      "posted_by_name": "John Doe",
      "image_paths": "uploads/pet_1_123456.jpg"
    }
  ]
}
```

#### 5. Get Pet Details
**Endpoint:** `GET /get_pet_details.php?pet_id=1`

**Response:**
```json
{
  "status": "success",
  "data": {
    "pet_id": "1",
    "pet_name": "Fluffy",
    "pet_type": "Cat",
    "age": "2 years",
    "gender": "Male",
    "health": "Healthy",
    "needs_help": false,
    "description": "Friendly orange tabby cat",
    "posted_by_name": "John Doe"
  }
}
```

#### 6. Get My Pets
**Endpoint:** `GET /get_my_pets.php?user_id=1`

**Response:** Same format as Get All Pets, filtered by user_id

### Adoption APIs

#### 7. Submit Adoption Request
**Endpoint:** `POST /submit_adoption_request.php`

**Request Body:**
```json
{
  "pet_id": "1",
  "user_id": "2",
  "motivation_message": "I have experience with cats and a loving home."
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Adoption request submitted successfully"
}
```

### Donation APIs

#### 8. Submit Donation
**Endpoint:** `POST /submit_donation.php`

**Request Body (Money):**
```json
{
  "pet_id": "1",
  "user_id": "2",
  "donation_type": "Money",
  "amount": "50.00"
}
```

**Request Body (Food/Medical):**
```json
{
  "pet_id": "1",
  "user_id": "2",
  "donation_type": "Food",
  "description": "5kg premium cat food"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Donation submitted successfully"
}
```

#### 9. Get My Donations
**Endpoint:** `GET /get_my_donations.php?user_id=1`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "donation_id": "1",
      "pet_id": "1",
      "pet_name": "Fluffy",
      "pet_type": "Cat",
      "donation_type": "Money",
      "amount": "50.00",
      "donation_date": "2024-01-15 10:30:00"
    }
  ]
}
```

### Profile APIs

#### 10. Get User Profile
**Endpoint:** `GET /get_user_profile.php?user_id=1`

**Response:**
```json
{
  "status": "success",
  "data": {
    "user_id": "1",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "1234567890",
    "profile_image": "uploads/profile_1_123456.jpg"
  }
}
```

#### 11. Update User Profile
**Endpoint:** `POST /update_user_profile.php`

**Request Body:**
```json
{
  "user_id": "1",
  "name": "John Smith",
  "phone": "9876543210",
  "profile_image": "data:image/jpeg;base64,..."
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Profile updated successfully",
  "data": {
    "user_id": "1",
    "name": "John Smith",
    "phone": "9876543210",
    "profile_image": "uploads/profile_1_123456.jpg"
  }
}
```

## Flutter App Configuration

### Base URL Configuration

Edit `lib/myconfig.dart`:

```dart
class MyConfig {
  // For Android Emulator: use "http://10.0.2.2"
  // For Physical Device: use "http://YOUR_COMPUTER_IP"
  String baseUrl = "http://10.0.2.2";
}
```

### Session Management

The app uses `SharedPreferences` to store user session data:
- User data is saved after successful login
- Session is loaded on app startup (splash screen)
- Profile updates are saved to both server and local storage

### Image Handling

- **Profile Images**: Saved to `server/pawpal/api/uploads/` with filename pattern: `profile_{user_id}_{timestamp}_{random}.jpg`
- **Pet Images**: Saved to `server/pawpal/api/uploads/` with filename pattern: `pet_{user_id}_{timestamp}_{random}_{index}.jpg`
- Images are uploaded as base64-encoded data URLs
- Maximum 3 images per pet submission

## Troubleshooting

### Common Build Issues

1. **APK Location Error**
   ```bash
   # The APK is built but Flutter can't find it
   # Solution: Use flutter run instead of flutter build
   flutter run -d <device-id>
   ```

2. **OneDrive File Locking**
   - Pause OneDrive sync temporarily
   - Or exclude `build/`, `.dart_tool/`, `android/.gradle/` from OneDrive

3. **Gradle Build Failures**
   ```bash
   # Clean and rebuild
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Location Shows Wrong Country**
   - Android emulators default to Google HQ (California)
   - Set custom location in emulator settings
   - Or use a physical device with GPS

### Common API Issues

1. **Connection Timeout**
   - Check `baseUrl` in `lib/myconfig.dart`
   - Ensure server is running
   - Verify firewall settings

2. **Foreign Key Constraint Errors**
   - Foreign keys use `ON DELETE CASCADE`
   - Deleting a user automatically deletes their pets, adoptions, and donations
   - No manual cleanup needed

3. **Image Upload Failures**
   - Ensure `api/uploads/` directory exists
   - Check write permissions (chmod 755)
   - Verify PHP `file_put_contents` is enabled

## Code Comments

### PHP API Files

All PHP API files include:
- **Header comments**: Explain the API endpoint purpose
- **Function comments**: Document helper functions
- **Inline comments**: Explain complex logic and validation
- **Error handling**: Comprehensive try-catch blocks with meaningful error messages

### Flutter Files

All Flutter files include:
- **Class comments**: Explain widget/screen purpose
- **Method comments**: Document function parameters and return values
- **State management**: Comments explaining state variables
- **API calls**: Comments showing request/response format
- **Form validation**: Comments explaining validation rules

### Key Files with Extensive Comments

- `server/pawpal/api/dbconnect.php` - Database connection with error handling
- `server/pawpal/api/submit_pet.php` - Image processing and validation logic
- `lib/views/submitpetpage.dart` - Location services and form handling
- `lib/views/profile_page.dart` - Image upload and session management
- `lib/views/public_pets_page.dart` - Search and filter implementation

## License

This project is for educational/demonstration purposes.


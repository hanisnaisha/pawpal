# PawPal

A Flutter mobile application for pet submissions with a PHP backend API. Users can register, login, submit pet information with images and location data, and view their submitted pets.

## Table of Contents

- [Setup Steps](#setup-steps)
- [API Explanation](#api-explanation)
- [Sample JSON](#sample-json)

## Setup Steps

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- PHP 7.4 or higher
- MySQL/MariaDB database
- Web server (Apache/Nginx) with PHP support
- Android Studio / Xcode (for mobile development)

### Backend Setup

1. **Database Configuration**
   - Create a MySQL database named `pawpal_db`
   - Update database credentials in `server/pawpal/api/dbconnect.php`:
     ```php
     $servername = "localhost";
     $username = "root";
     $password = "";
     $dbname = "pawpal_db";
     ```

2. **Database Tables**
   - Create `tbl_users` table with columns:
     - `user_id` (INT, AUTO_INCREMENT, PRIMARY KEY)
     - `name` or `user_name` (VARCHAR)
     - `email` or `user_email` (VARCHAR, UNIQUE)
     - `password` or `user_password` (VARCHAR) - stores SHA1 hashed passwords
     - `phone` or `user_phone` (VARCHAR)
     - `user_regdate` or similar (DATETIME, optional)
   
   - Create `tbl_pets` table with columns:
     - `pet_id` (INT, AUTO_INCREMENT, PRIMARY KEY)
     - `user_id` (INT, FOREIGN KEY to tbl_users)
     - `pet_name` (VARCHAR)
     - `pet_type` (VARCHAR) - e.g., "Cat", "Dog", "Rabbit", "Other"
     - `submission_category` (VARCHAR) - e.g., "Lost", "Found", "Adoption"
     - `description` (TEXT)
     - `latitude` (DECIMAL)
     - `longitude` (DECIMAL)
     - `image_paths` (TEXT) - comma-separated paths or JSON array
     - `submission_date` (DATETIME)

3. **Server Setup**
   - Copy the `server/pawpal` directory to your web server's document root
   - Ensure the `api/uploads/` directory exists and has write permissions (chmod 755)
   - Configure CORS if needed (already set to allow all origins in the API files)

### Flutter App Setup

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure Base URL**
   - Update `lib/myconfig.dart` with your server's IP address or domain:
     ```dart
     String baseUrl = "http://YOUR_SERVER_IP";
     ```
   - For local development, use your local IP address (e.g., `http://10.29.199.64`)
   - For production, use your domain name

3. **Run the Application**
   ```bash
   flutter run
   ```

### Permissions

The app requires the following permissions (configured in Android/iOS):
- **Location**: For capturing pet location coordinates
- **Camera/Gallery**: For selecting pet images
- **Internet**: For API communication

## API Explanation

All API endpoints are located in `server/pawpal/api/` and return JSON responses.

### Base URL
```
http://YOUR_SERVER_IP/pawpal/api/
```

### Endpoints

#### 1. User Registration
**Endpoint:** `POST /register_user.php`

**Description:** Registers a new user account.

**Request Parameters:**
- `name` (string, required) - User's full name
- `email` (string, required) - User's email address (must be valid email format)
- `password` (string, required) - User's password (will be hashed with SHA1)
- `phone` (string, required) - User's phone number

**Response:**
- Success: `{"status": "success", "message": "User registered successfully"}`
- Error: `{"status": "failed", "message": "Error message"}`

**Status Codes:**
- `200` - Success
- `400` - Bad Request (missing fields or invalid email)
- `405` - Method Not Allowed
- `500` - Server Error

---

#### 2. User Login
**Endpoint:** `POST /login_user.php`

**Description:** Authenticates a user and returns user data.

**Request Parameters:**
- `email` (string, required) - User's email address
- `password` (string, required) - User's password (will be hashed with SHA1 for comparison)

**Response:**
- Success: `{"status": "success", "message": "Login successful", "data": {...user data...}}`
- Error: `{"status": "failed", "message": "Invalid email or password", "data": null}`

**Status Codes:**
- `200` - Success
- `400` - Bad Request
- `405` - Method Not Allowed
- `500` - Server Error

---

#### 3. Get My Pets
**Endpoint:** `GET /get_my_pets.php` or `POST /get_my_pets.php`

**Description:** Retrieves pets submitted by a specific user. Supports optional filtering.

**Query Parameters (GET) or Request Body (POST):**
- `user_id` (string, optional) - Filter by user ID. If provided, returns only pets for that user
- `pet_type` (string, optional) - Filter by pet type (e.g., "Cat", "Dog", "Rabbit", "Other"). Use "All" to get all types
- `category` (string, optional) - Filter by submission category (e.g., "Lost", "Found", "Adoption")

**Response:**
- Success: `{"status": "success", "message": "Pets retrieved successfully", "data": [...pets array...], "count": number}`
- Error: `{"status": "failed", "message": "Error message"}`

**Status Codes:**
- `200` - Success
- `405` - Method Not Allowed
- `500` - Server Error

---

#### 4. Submit Pet
**Endpoint:** `POST /submit_pet.php`

**Description:** Submits a new pet entry with images and location data.

**Request Body (JSON or Form Data):**
- `user_id` (string, required) - ID of the user submitting the pet
- `pet_name` (string, required) - Name of the pet
- `pet_type` (string, required) - Type of pet (e.g., "Cat", "Dog", "Rabbit", "Other")
- `category` or `submission_category` (string, required) - Submission category (e.g., "Lost", "Found", "Adoption")
- `description` (string, required) - Description of the pet (minimum 10 characters)
- `lat` or `latitude` (float, required) - Latitude coordinate
- `lng` or `longitude` (float, required) - Longitude coordinate
- `images` (array, required) - Array of Base64-encoded image strings (1-3 images maximum)

**Response:**
- Success: `{"success": true, "message": "Pet submitted successfully"}`
- Error: `{"success": false, "message": "Error message"}`

**Status Codes:**
- `200` - Success
- `400` - Bad Request (missing fields, invalid data, too many images, etc.)
- `405` - Method Not Allowed
- `500` - Server Error

**Notes:**
- Images are saved to `api/uploads/` directory
- Image filenames follow pattern: `pet_{user_id}_{timestamp}_{random}_{index}.jpg`
- Maximum 3 images per submission
- Description must be at least 10 characters long

---

## Sample JSON

### User Registration Request
```json
{
  "name": "Hanis",
  "email": "hanis@gmail.com",
  "password": "mypassword123",
  "phone": "1234567890"
}
```

### User Registration Response (Success)
```json
{
  "status": "success",
  "message": "User registered successfully"
}
```

### User Registration Response (Error)
```json
{
  "status": "failed",
  "message": "Email already registered"
}
```

---

### User Login Request
```json
{
  "email": "hanis@gmail.com",
  "password": "mypassword123"
}
```

### User Login Response (Success)
```json
{
  "status": "success",
  "message": "Login successful",
  "data": {
    "user_id": "1",
    "name": "Hanis",
    "email": "hanis@gmail.com",
    "phone": "1234567890",
    "user_regdate": "2024-01-15 10:30:00"
  }
}
```

### User Login Response (Error)
```json
{
  "status": "failed",
  "message": "Invalid email or password",
  "data": null
}
```

---

### Get My Pets Request
```
GET /pawpal/api/get_my_pets.php?user_id=1&pet_type=Cat
```

### Get My Pets Response (Success)
```json
{
  "status": "success",
  "message": "Pets retrieved successfully",
  "data": [
    {
      "pet_id": "1",
      "user_id": "1",
      "pet_name": "Fluffy",
      "pet_type": "Cat",
      "submission_category": "Lost",
      "description": "A friendly orange tabby cat with white paws. Last seen near the park.",
      "latitude": 3.1390,
      "longitude": 101.6869,
      "submission_date": "2024-01-20 14:30:00",
      "image_paths": [
        "uploads/pet_1_1705752600_a1b2c3d4_1.jpg",
        "uploads/pet_1_1705752600_a1b2c3d4_2.jpg"
      ]
    },
    {
      "pet_id": "2",
      "user_id": "1",
      "pet_name": "Max",
      "pet_type": "Dog",
      "submission_category": "Found",
      "description": "Found a friendly golden retriever near the shopping mall. Very well-behaved.",
      "latitude": 3.1400,
      "longitude": 101.6870,
      "submission_date": "2024-01-21 09:15:00",
      "image_paths": [
        "uploads/pet_1_1705839300_e5f6g7h8_1.jpg"
      ]
    }
  ],
  "count": 2
}
```

### Get My Pets Response (No Pets)
```json
{
  "status": "success",
  "message": "Pets retrieved successfully",
  "data": [],
  "count": 0
}
```

---

### Submit Pet Request
```json
{
  "user_id": "1",
  "pet_name": "Fluffy",
  "pet_type": "Cat",
  "submission_category": "Lost",
  "description": "A friendly orange tabby cat with white paws. Last seen near the park yesterday afternoon.",
  "lat": 3.1390,
  "lng": 101.6869,
  "images": [
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
  ]
}
```

**Note:** The `images` array contains Base64-encoded image strings. In practice, these would be much longer strings representing actual image data.

### Submit Pet Response (Success)
```json
{
  "success": true,
  "message": "Pet submitted successfully"
}
```

### Submit Pet Response (Error - Missing Fields)
```json
{
  "success": false,
  "message": "Missing required fields"
}
```

### Submit Pet Response (Error - Too Many Images)
```json
{
  "success": false,
  "message": "Maximum 3 images allowed"
}
```

### Submit Pet Response (Error - Description Too Short)
```json
{
  "success": false,
  "message": "Description must be at least 10 characters"
}
```

---

## Additional Notes

- All passwords are hashed using SHA1 algorithm before storage
- Image paths are stored as comma-separated strings in the database
- The API supports both JSON and form-data request formats
- All endpoints include CORS headers allowing cross-origin requests
- Error responses include appropriate HTTP status codes
- Pet IDs and User IDs are automatically reordered sequentially if gaps are detected

## License

This project is for educational/demonstration purposes.

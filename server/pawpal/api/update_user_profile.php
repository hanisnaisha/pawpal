<?php
// Update user profile
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

require_once 'dbconnect.php';

function sendJsonResponse($sentArray) {
    ob_clean();
    header('Content-Type: application/json');
    echo json_encode($sentArray);
    exit();
}

try {
    if (!isset($conn) || !$conn) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database connection failed"));
    }
    
    if (property_exists($conn, 'connect_error') && $conn->connect_error) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database connection error: " . $conn->connect_error));
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        sendJsonResponse(array("status" => "failed", "message" => "Method Not Allowed"));
    }
    
    // Get JSON or form data
    $data = array();
    $json = file_get_contents('php://input');
    if (!empty($json)) {
        $data = json_decode($json, true);
        if (!$data) {
            $data = $_POST;
        }
    } else {
        $data = $_POST;
    }
    
    // Validate required fields
    if (!isset($data['user_id'])) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "User ID is required"));
    }
    
    $userId = trim($data['user_id']);
    $userId = $conn->real_escape_string($userId);
    
    // Build UPDATE query dynamically based on provided fields
    $updateFields = array();
    
    if (isset($data['name']) && !empty(trim($data['name']))) {
        $name = $conn->real_escape_string(trim($data['name']));
        $updateFields[] = "`name` = '$name'";
    }
    
    if (isset($data['phone']) && !empty(trim($data['phone']))) {
        $phone = $conn->real_escape_string(trim($data['phone']));
        $updateFields[] = "`phone` = '$phone'";
    }
    
    /**
     * Handle Profile Image Upload
     * 
     * REQUIREMENT: Store updated image on server filesystem
     * 
     * This section processes profile image uploads:
     * 1. Accepts base64-encoded image data from Flutter app
     * 2. Decodes base64 to binary image data
     * 3. Saves image to server filesystem (uploads/ directory)
     * 4. Deletes old profile image to save disk space
     * 5. Stores relative file path in database (not base64 data)
     * 
     * Image Storage:
     * - Location: server/pawpal/api/uploads/
     * - Filename format: profile_{user_id}_{timestamp}_{random}.jpg
     * - Path stored in DB: uploads/profile_1_1234567890_abcd1234.jpg
     * 
     * This ensures images persist on server and can be accessed via URL
     */
    if (isset($data['profile_image']) && !empty(trim($data['profile_image']))) {
        // Handle base64 image - save to filesystem like pet images
        $profileImageData = trim($data['profile_image']);
        
        // Check if it's a data URL (data:image/jpeg;base64,...)
        if (strpos($profileImageData, 'data:image') === 0) {
            // Remove data URL prefix (e.g., "data:image/jpeg;base64,")
            $base64Image = preg_replace('/^data:image\/\w+;base64,/', '', $profileImageData);
            
            // Decode Base64 string to binary image data
            $imageData = base64_decode($base64Image, true);
            
            if ($imageData === false) {
                http_response_code(400);
                sendJsonResponse(array("status" => "failed", "message" => "Invalid image data"));
            }
            
            // Create uploads directory if it doesn't exist
            // This directory stores all uploaded images (profile and pet images)
            $uploadsDir = 'uploads/';
            if (!file_exists($uploadsDir)) {
                if (!mkdir($uploadsDir, 0755, true)) {
                    http_response_code(500);
                    sendJsonResponse(array("status" => "failed", "message" => "Failed to create uploads directory"));
                }
            }
            
            // Generate unique filename to prevent conflicts
            // Format: profile_{user_id}_{timestamp}_{random}.jpg
            $timestamp = time();
            $randomString = bin2hex(random_bytes(4));
            $filename = "profile_" . $userId . "_" . $timestamp . "_" . $randomString . ".jpg";
            $filepath = $uploadsDir . $filename;
            
            // REQUIREMENT: Save image to server filesystem
            // This ensures the image persists on the server and can be accessed via URL
            $bytesWritten = file_put_contents($filepath, $imageData);
            
            if ($bytesWritten === false || !file_exists($filepath)) {
                http_response_code(500);
                sendJsonResponse(array("status" => "failed", "message" => "Failed to save profile image"));
            }
            
            // Delete old profile image if exists to save disk space
            // Only one profile image per user should exist
            $oldImageResult = $conn->query("SELECT profile_image FROM tbl_users WHERE user_id = '$userId'");
            if ($oldImageResult && $oldImageResult->num_rows > 0) {
                $oldUserData = $oldImageResult->fetch_assoc();
                if (!empty($oldUserData['profile_image'])) {
                    $oldImagePath = $oldUserData['profile_image'];
                    // Check if it's a relative path
                    if (!file_exists($oldImagePath) && file_exists('uploads/' . basename($oldImagePath))) {
                        $oldImagePath = 'uploads/' . basename($oldImagePath);
                    }
                    if (file_exists($oldImagePath)) {
                        @unlink($oldImagePath);  // Delete old image file
                    }
                }
            }
            
            // Store relative path in database (not base64 data)
            // This allows the image to be accessed via URL: baseUrl/pawpal/api/uploads/filename.jpg
            $relativePath = "uploads/" . $filename;
            $profileImage = $conn->real_escape_string($relativePath);
            $updateFields[] = "`profile_image` = '$profileImage'";
        } else {
            // Assume it's already a path (for backward compatibility)
            $profileImage = $conn->real_escape_string($profileImageData);
            $updateFields[] = "`profile_image` = '$profileImage'";
        }
    }
    
    if (empty($updateFields)) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "No fields to update"));
    }
    
    $updateClause = implode(', ', $updateFields);
    $sql = "UPDATE `tbl_users` SET $updateClause WHERE `user_id` = '$userId'";
    
    if ($conn->query($sql) === TRUE) {
        // Get updated user data
        $selectSql = "SELECT * FROM `tbl_users` WHERE `user_id` = '$userId'";
        $result = $conn->query($selectSql);
        
        if ($result && $result->num_rows > 0) {
            $userData = $result->fetch_assoc();
            sendJsonResponse(array(
                "status" => "success",
                "message" => "Profile updated successfully",
                "data" => $userData
            ));
        } else {
            sendJsonResponse(array(
                "status" => "success",
                "message" => "Profile updated successfully"
            ));
        }
    } else {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Failed to update profile: " . $conn->error));
    }
    
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    sendJsonResponse(array("status" => "failed", "message" => "Server error: " . $e->getMessage()));
} catch (Error $e) {
    http_response_code(500);
    sendJsonResponse(array("status" => "failed", "message" => "Fatal error: " . $e->getMessage()));
}
?>

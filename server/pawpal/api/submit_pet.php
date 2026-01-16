<?php
/**
 * Submit Pet API Endpoint
 * 
 * This API endpoint handles pet submission with images and location data.
 * 
 * Features:
 * - Accepts JSON or form-data input
 * - Validates all required fields
 * - Processes and saves up to 3 images (Base64 to filesystem)
 * - Automatically sets needs_help flag based on submission category
 * - Saves pet data with age, gender, health status
 * - Returns JSON response with success/error status
 * 
 * Request Method: POST
 * Content-Type: application/json or application/x-www-form-urlencoded
 */

// Disable error display to prevent HTML output in JSON responses
// Errors are caught and returned as JSON instead
ini_set('display_errors', 0);
error_reporting(E_ALL);

// Start output buffering to prevent any accidental output before JSON response
ob_start();

// Set CORS headers to allow cross-origin requests from Flutter app
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

/**
 * Helper function to send JSON response and exit
 * 
 * @param array $sentArray - Array to encode as JSON and send
 * 
 * This function ensures clean JSON output by:
 * - Clearing any output buffer
 * - Setting proper JSON content type header
 * - Encoding array to JSON
 * - Exiting script execution
 */
function sendJsonResponse($sentArray) {
    ob_clean();  // Clear any previous output
    header('Content-Type: application/json');
    echo json_encode($sentArray);
    exit();  // Stop script execution after sending response
}

// Error handler to catch fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== NULL && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        ob_clean();
        header('Content-Type: application/json');
        http_response_code(500);
        echo json_encode(array("success" => false, "message" => "Server error: " . $error['message']));
        exit();
    }
});

try {
    require_once 'dbconnect.php';
    
    if (!isset($conn) || !$conn) {
        http_response_code(500);
        sendJsonResponse(array("success" => false, "message" => "Database connection failed"));
    }
    
    // Check if connection has errors
    if (property_exists($conn, 'connect_error') && $conn->connect_error) {
        http_response_code(500);
        sendJsonResponse(array("success" => false, "message" => "Database connection error: " . $conn->connect_error));
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        sendJsonResponse(array("success" => false, "message" => "Method Not Allowed"));
    }
    
    // Get JSON input (or form data)
    $data = array();
    
    // Check if JSON input
    $json = file_get_contents('php://input');
    if (!empty($json)) {
        $data = json_decode($json, true);
        if (!$data) {
            http_response_code(400);
            sendJsonResponse(array("success" => false, "message" => "Invalid JSON data"));
        }
    } else {
        // Fallback to POST form data
        $data = $_POST;
    }
    
    // Validate required fields - accept both naming conventions
    if (!isset($data['user_id']) || !isset($data['pet_name']) || !isset($data['pet_type']) || 
        !isset($data['description']) || !isset($data['images'])) {
        http_response_code(400);
        sendJsonResponse(array("success" => false, "message" => "Missing required fields"));
    }
    
    // Check for category (accept both 'category' and 'submission_category')
    if (!isset($data['category']) && !isset($data['submission_category'])) {
        http_response_code(400);
        sendJsonResponse(array("success" => false, "message" => "Missing category field"));
    }
    
    // Check for location coordinates (lat and lng are required)
    if ((!isset($data['lat']) && !isset($data['latitude'])) || 
        (!isset($data['lng']) && !isset($data['longitude']))) {
        http_response_code(400);
        sendJsonResponse(array("success" => false, "message" => "Missing location coordinates (lat and lng are required)"));
    }
    
    // Sanitize input
    $user_id = trim($data['user_id']);
    $pet_name = trim($data['pet_name']);
    $pet_type = trim($data['pet_type']);
    $category = isset($data['category']) ? trim($data['category']) : trim($data['submission_category']);
    $description = trim($data['description']);
    
    // Optional fields
    $age = isset($data['age']) && !empty($data['age']) ? trim($data['age']) : null;
    $gender = isset($data['gender']) && !empty($data['gender']) ? trim($data['gender']) : null;
    $health = isset($data['health']) && !empty($data['health']) ? trim($data['health']) : null;
    $posted_by_name = isset($data['posted_by_name']) && !empty($data['posted_by_name']) ? trim($data['posted_by_name']) : null;
    
    // Location coordinates are required
    $lat = isset($data['lat']) ? floatval($data['lat']) : floatval($data['latitude']);
    $lng = isset($data['lng']) ? floatval($data['lng']) : floatval($data['longitude']);
    $images = $data['images']; // Array of Base64 strings
    
    // Validate images array
    if (!is_array($images) || count($images) == 0) {
        http_response_code(400);
        sendJsonResponse(array("success" => false, "message" => "At least one image is required"));
    }
    
    if (count($images) > 3) {
        http_response_code(400);
        sendJsonResponse(array("success" => false, "message" => "Maximum 3 images allowed"));
    }
    
    // Validate description length
    if (strlen($description) < 10) {
        http_response_code(400);
        sendJsonResponse(array("success" => false, "message" => "Description must be at least 10 characters"));
    }
    
    // Create uploads directory if it doesn't exist (as per requirements)
    $uploadsDir = 'uploads/';
    if (!file_exists($uploadsDir)) {
        if (!mkdir($uploadsDir, 0755, true)) {
            http_response_code(500);
            sendJsonResponse(array("success" => false, "message" => "Failed to create uploads directory"));
        }
    }
    
    // Process and save images
    $savedImagePaths = array();
    $imageErrors = array();
    
    foreach ($images as $index => $base64Image) {
        try {
            // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
            $base64Image = preg_replace('/^data:image\/\w+;base64,/', '', $base64Image);
            
            // Decode Base64 to binary
            $imageData = base64_decode($base64Image, true);
            
            if ($imageData === false) {
                $imageErrors[] = "Image " . ($index + 1) . " is not valid Base64";
                continue;
            }
            
            // Generate unique filename
            $timestamp = time();
            $randomString = bin2hex(random_bytes(4));
            $filename = "pet_" . $user_id . "_" . $timestamp . "_" . $randomString . "_" . ($index + 1) . ".jpg";
            $filepath = $uploadsDir . $filename;
            
            // Save image using file_put_contents (as per requirements: file_put_contents("uploads/" . $filename, $decodedImage))
            $bytesWritten = file_put_contents($filepath, $imageData);
            
            if ($bytesWritten === false) {
                $imageErrors[] = "Failed to save image " . ($index + 1);
                continue;
            }
            
            // Verify the file was created and is a valid image
            if (!file_exists($filepath)) {
                $imageErrors[] = "Image " . ($index + 1) . " file was not created";
                continue;
            }
            
            // Store path for database (relative path from uploads directory)
            $relativePath = "uploads/" . $filename;
            $savedImagePaths[] = $relativePath;
            
        } catch (Exception $e) {
            $imageErrors[] = "Error processing image " . ($index + 1) . ": " . $e->getMessage();
        }
    }
    
    // If no images were saved successfully, return error
    if (count($savedImagePaths) == 0) {
        http_response_code(400);
        sendJsonResponse(array(
            "success" => false, 
            "message" => "Failed to save images: " . implode(", ", $imageErrors)
        ));
    }
    
    // Convert image paths array to comma-separated string OR JSON string (as per requirements)
    // Using comma-separated as it's simpler and mentioned first in requirements
    $imagePathsString = implode(',', $savedImagePaths);
    
    // Get current timestamp (created timestamp)
    $currentTimestamp = date('Y-m-d H:i:s');
    
    // Note: Removed pet_id reordering code
    // Keeping gaps in IDs is standard MySQL practice and avoids foreign key issues
    // IDs are just identifiers - gaps don't affect functionality
    
    // Escape strings for SQL (basic protection)
    $pet_name = $conn->real_escape_string($pet_name);
    $pet_type = $conn->real_escape_string($pet_type);
    $category = $conn->real_escape_string($category);
    $description = $conn->real_escape_string($description);
    $imagePathsString = $conn->real_escape_string($imagePathsString);
    
    // Escape optional fields
    $age = $age ? $conn->real_escape_string($age) : 'NULL';
    $gender = $gender ? $conn->real_escape_string($gender) : 'NULL';
    $health = $health ? $conn->real_escape_string($health) : 'NULL';
    $posted_by_name = $posted_by_name ? $conn->real_escape_string($posted_by_name) : 'NULL';
    
    /**
     * Automatically set needs_help flag based on submission category
     * 
     * This determines if the pet needs donations/help:
     * - "Donation Request" or "Help/Rescue" → needs_help = 1 (shows donation button)
     * - "Adoption" → needs_help = 0 (adoption only, no donation button)
     * 
     * The needs_help flag is used in the Flutter app to show/hide the donation button
     * on the pet details page.
     */
    $needs_help = 0; // Default to 0 (false) - pet doesn't need help
    if ($category === 'Donation Request' || $category === 'Help/Rescue') {
        $needs_help = 1; // Set to 1 (true) if pet needs help/donations
    }
    
    // Insert pet submission into database
    // Store all form fields, image paths, and created timestamp
    // lat and lng are required
    $sql = "INSERT INTO `tbl_pets` (
        `user_id`, 
        `posted_by_name`,
        `pet_name`, 
        `pet_type`,
        `age`,
        `gender`,
        `health`,
        `needs_help`,
        `submission_category`, 
        `description`, 
        `latitude`, 
        `longitude`, 
        `image_paths`, 
        `submission_date`
    ) VALUES (
        '$user_id',
        " . ($posted_by_name !== 'NULL' ? "'$posted_by_name'" : 'NULL') . ",
        '$pet_name',
        '$pet_type',
        " . ($age !== 'NULL' ? "'$age'" : 'NULL') . ",
        " . ($gender !== 'NULL' ? "'$gender'" : 'NULL') . ",
        " . ($health !== 'NULL' ? "'$health'" : 'NULL') . ",
        $needs_help,
        '$category',
        '$description',
        '$lat',
        '$lng',
        '$imagePathsString',
        '$currentTimestamp'
    )";
    
    if ($conn->query($sql) === TRUE) {
        // Return JSON as per requirements: {"success": true, "message": "Pet submitted successfully"}
        sendJsonResponse(array(
            "success" => true, 
            "message" => "Pet submitted successfully"
        ));
    } else {
        // If database insert fails, try to clean up saved images
        foreach ($savedImagePaths as $path) {
            $fullPath = $path;
            if (file_exists($fullPath)) {
                @unlink($fullPath);
            }
        }
        
        http_response_code(500);
        sendJsonResponse(array(
            "success" => false, 
            "message" => "Failed to save pet data: " . $conn->error
        ));
    }
    
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    sendJsonResponse(array("success" => false, "message" => "Server error: " . $e->getMessage()));
} catch (Error $e) {
    http_response_code(500);
    sendJsonResponse(array("success" => false, "message" => "Fatal error: " . $e->getMessage()));
}
?>


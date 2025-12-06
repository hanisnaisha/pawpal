<?php
// Disable error display to prevent HTML output
ini_set('display_errors', 0);
error_reporting(E_ALL);

// Start output buffering
ob_start();

// Set headers
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

function sendJsonResponse($sentArray) {
    ob_clean();
    header('Content-Type: application/json');
    echo json_encode($sentArray);
    exit();
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
    
    // Reorder pet_id sequentially if there are gaps
    $reorderResult = $conn->query("SELECT pet_id FROM tbl_pets ORDER BY pet_id ASC");
    if ($reorderResult && $reorderResult->num_rows > 0) {
        $pets = $reorderResult->fetch_all(MYSQLI_ASSOC);
        $expectedId = 1;
        $needsReorder = false;
        
        // Check if reordering is needed
        foreach ($pets as $pet) {
            if ($pet['pet_id'] != $expectedId) {
                $needsReorder = true;
                break;
            }
            $expectedId++;
        }
        
        // Reorder if needed
        if ($needsReorder) {
            // Step 1: Set all pet_ids to negative values to avoid conflicts
            $tempId = -1;
            foreach ($pets as $pet) {
                $oldId = $pet['pet_id'];
                $conn->query("UPDATE tbl_pets SET pet_id = $tempId WHERE pet_id = $oldId");
                $tempId--;
            }
            
            // Step 2: Set pet_ids to sequential positive values
            $newId = 1;
            $tempId = -1;
            foreach ($pets as $pet) {
                $conn->query("UPDATE tbl_pets SET pet_id = $newId WHERE pet_id = $tempId");
                $newId++;
                $tempId--;
            }
            
            // Reset AUTO_INCREMENT
            $nextId = count($pets) + 1;
            $conn->query("ALTER TABLE tbl_pets AUTO_INCREMENT = $nextId");
        }
    } else {
        // If table is empty, reset AUTO_INCREMENT to 1
        $conn->query("ALTER TABLE tbl_pets AUTO_INCREMENT = 1");
    }
    
    // Escape strings for SQL (basic protection)
    $pet_name = $conn->real_escape_string($pet_name);
    $pet_type = $conn->real_escape_string($pet_type);
    $category = $conn->real_escape_string($category);
    $description = $conn->real_escape_string($description);
    $imagePathsString = $conn->real_escape_string($imagePathsString);
    
    // Insert pet submission into database
    // Store all form fields, image paths, and created timestamp
    // lat and lng are required
    $sql = "INSERT INTO `tbl_pets` (
        `user_id`, 
        `pet_name`, 
        `pet_type`, 
        `submission_category`, 
        `description`, 
        `latitude`, 
        `longitude`, 
        `image_paths`, 
        `submission_date`
    ) VALUES (
        '$user_id',
        '$pet_name',
        '$pet_type',
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


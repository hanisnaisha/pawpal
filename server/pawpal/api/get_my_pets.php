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
        echo json_encode(array("status" => "failed", "message" => "Server error: " . $error['message']));
        exit();
    }
});

try {
    require_once 'dbconnect.php';
    
    if (!isset($conn) || !$conn) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database connection failed"));
    }
    
    // Check if connection has errors
    if (property_exists($conn, 'connect_error') && $conn->connect_error) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database connection error: " . $conn->connect_error));
    }

    // Accept both GET and POST for flexibility
    if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        sendJsonResponse(array("status" => "failed", "message" => "Method Not Allowed"));
    }
    
    // Optional filters
    $petTypeFilter = isset($_GET['pet_type']) ? trim($_GET['pet_type']) : null;
    $categoryFilter = isset($_GET['category']) ? trim($_GET['category']) : null;
    $userIdFilter = isset($_GET['user_id']) ? trim($_GET['user_id']) : null;
    
    // Build SQL query
    $sql = "SELECT * FROM `tbl_pets` WHERE 1=1";
    
    if ($petTypeFilter && $petTypeFilter !== 'All') {
        $petTypeFilter = $conn->real_escape_string($petTypeFilter);
        $sql .= " AND `pet_type` = '$petTypeFilter'";
    }
    
    if ($categoryFilter) {
        $categoryFilter = $conn->real_escape_string($categoryFilter);
        $sql .= " AND `submission_category` = '$categoryFilter'";
    }
    
    if ($userIdFilter) {
        $userIdFilter = $conn->real_escape_string($userIdFilter);
        $sql .= " AND `user_id` = '$userIdFilter'";
    }
    
    // Order by submission date (newest first)
    $sql .= " ORDER BY `submission_date` DESC";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database query error: " . $conn->error));
    }
    
    $pets = array();
    
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            // Parse image_paths - handle both comma-separated and JSON
            $imagePaths = array();
            if (isset($row['image_paths']) && !empty($row['image_paths'])) {
                // Check if it's comma-separated
                if (strpos($row['image_paths'], ',') !== false && strpos($row['image_paths'], '[') === false) {
                    $imagePaths = explode(',', $row['image_paths']);
                    $imagePaths = array_map('trim', $imagePaths);
                } else {
                    // Try JSON decode
                    $decodedPaths = json_decode($row['image_paths'], true);
                    if (is_array($decodedPaths)) {
                        $imagePaths = $decodedPaths;
                    } else if (is_string($row['image_paths'])) {
                        $imagePaths = array($row['image_paths']);
                    }
                }
            }
            
            // Build pet data array
            $petData = array(
                "pet_id" => isset($row['pet_id']) ? $row['pet_id'] : (isset($row['id']) ? $row['id'] : null),
                "user_id" => isset($row['user_id']) ? $row['user_id'] : null,
                "pet_name" => isset($row['pet_name']) ? $row['pet_name'] : (isset($row['name']) ? $row['name'] : null),
                "pet_type" => isset($row['pet_type']) ? $row['pet_type'] : (isset($row['type']) ? $row['type'] : null),
                "submission_category" => isset($row['submission_category']) ? $row['submission_category'] : (isset($row['category']) ? $row['category'] : null),
                "description" => isset($row['description']) ? $row['description'] : null,
                "latitude" => isset($row['latitude']) ? floatval($row['latitude']) : null,
                "longitude" => isset($row['longitude']) ? floatval($row['longitude']) : null,
                "submission_date" => isset($row['submission_date']) ? $row['submission_date'] : (isset($row['date']) ? $row['date'] : null),
                "image_paths" => $imagePaths
            );
            
            $pets[] = $petData;
        }
    }
    
    sendJsonResponse(array(
        "status" => "success",
        "message" => "Pets retrieved successfully",
        "data" => $pets,
        "count" => count($pets)
    ));
    
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    sendJsonResponse(array("status" => "failed", "message" => "Server error: " . $e->getMessage()));
} catch (Error $e) {
    http_response_code(500);
    sendJsonResponse(array("status" => "failed", "message" => "Fatal error: " . $e->getMessage()));
}
?>


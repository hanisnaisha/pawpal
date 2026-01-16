<?php
// Get detailed information about a specific pet
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

    if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        sendJsonResponse(array("status" => "failed", "message" => "Method Not Allowed"));
    }
    
    // Get pet_id from query or POST
    $petId = isset($_GET['pet_id']) ? trim($_GET['pet_id']) : (isset($_POST['pet_id']) ? trim($_POST['pet_id']) : null);
    
    if (!$petId) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "Pet ID is required"));
    }
    
    $petId = $conn->real_escape_string($petId);
    
    // Get pet details with user information
    $sql = "SELECT p.*, u.name as posted_by_name, u.email as posted_by_email 
            FROM `tbl_pets` p 
            LEFT JOIN `tbl_users` u ON p.user_id = u.user_id 
            WHERE p.`pet_id` = '$petId'";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database query error: " . $conn->error));
    }
    
    if ($result->num_rows == 0) {
        http_response_code(404);
        sendJsonResponse(array("status" => "failed", "message" => "Pet not found"));
    }
    
    $row = $result->fetch_assoc();
    
    // Parse image_paths
    $imagePaths = array();
    if (isset($row['image_paths']) && !empty($row['image_paths'])) {
        if (strpos($row['image_paths'], ',') !== false && strpos($row['image_paths'], '[') === false) {
            $imagePaths = explode(',', $row['image_paths']);
            $imagePaths = array_map('trim', $imagePaths);
        } else {
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
        "pet_id" => $row['pet_id'],
        "user_id" => $row['user_id'],
        "pet_name" => $row['pet_name'],
        "pet_type" => $row['pet_type'],
        "age" => isset($row['age']) ? $row['age'] : null,
        "gender" => isset($row['gender']) ? $row['gender'] : null,
        "health" => isset($row['health']) ? $row['health'] : null,
        "needs_help" => isset($row['needs_help']) ? (bool)$row['needs_help'] : false,
        "submission_category" => $row['submission_category'],
        "description" => $row['description'],
        "latitude" => isset($row['latitude']) ? floatval($row['latitude']) : null,
        "longitude" => isset($row['longitude']) ? floatval($row['longitude']) : null,
        "submission_date" => $row['submission_date'],
        "posted_by_name" => isset($row['posted_by_name']) ? $row['posted_by_name'] : null,
        "posted_by_email" => isset($row['posted_by_email']) ? $row['posted_by_email'] : null,
        "image_paths" => $imagePaths
    );
    
    sendJsonResponse(array(
        "status" => "success",
        "message" => "Pet details retrieved successfully",
        "data" => $petData
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

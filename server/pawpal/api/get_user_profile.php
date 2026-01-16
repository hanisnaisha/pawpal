<?php
// Get user profile by user_id
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

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        sendJsonResponse(array("status" => "failed", "message" => "Method Not Allowed"));
    }
    
    // Get user_id from query
    $userId = isset($_GET['user_id']) ? trim($_GET['user_id']) : null;
    
    if (!$userId) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "User ID is required"));
    }
    
    $userId = $conn->real_escape_string($userId);
    
    // Get user data
    $sql = "SELECT * FROM `tbl_users` WHERE `user_id` = '$userId'";
    $result = $conn->query($sql);
    
    if (!$result) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database query error: " . $conn->error));
    }
    
    if ($result->num_rows > 0) {
        $userData = $result->fetch_assoc();
        sendJsonResponse(array(
            "status" => "success",
            "message" => "User profile retrieved successfully",
            "data" => $userData
        ));
    } else {
        http_response_code(404);
        sendJsonResponse(array("status" => "failed", "message" => "User not found"));
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

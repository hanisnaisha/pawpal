<?php
// Submit adoption request
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
    if (!isset($data['pet_id']) || !isset($data['user_id']) || !isset($data['motivation_message'])) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "Missing required fields: pet_id, user_id, and motivation_message are required"));
    }
    
    $petId = trim($data['pet_id']);
    $userId = trim($data['user_id']);
    $motivationMessage = trim($data['motivation_message']);
    
    // Validate motivation message is not empty
    if (empty($motivationMessage)) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "Motivation message cannot be empty"));
    }
    
    // Escape strings
    $petId = $conn->real_escape_string($petId);
    $userId = $conn->real_escape_string($userId);
    $motivationMessage = $conn->real_escape_string($motivationMessage);
    
    // Insert adoption request
    $sql = "INSERT INTO `tbl_adoptions` (`pet_id`, `user_id`, `motivation_message`, `status`) 
            VALUES ('$petId', '$userId', '$motivationMessage', 'pending')";
    
    if ($conn->query($sql) === TRUE) {
        sendJsonResponse(array(
            "status" => "success",
            "message" => "Adoption request submitted successfully"
        ));
    } else {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Failed to submit adoption request: " . $conn->error));
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

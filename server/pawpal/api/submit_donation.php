<?php
// Submit donation
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
    if (!isset($data['pet_id']) || !isset($data['user_id']) || !isset($data['donation_type'])) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "Missing required fields: pet_id, user_id, and donation_type are required"));
    }
    
    $petId = trim($data['pet_id']);
    $userId = trim($data['user_id']);
    $donationType = trim($data['donation_type']);
    
    // Validate donation type
    $validTypes = array('Food', 'Medical', 'Money');
    if (!in_array($donationType, $validTypes)) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "Invalid donation type. Must be: Food, Medical, or Money"));
    }
    
    $amount = null;
    $description = null;
    
    if ($donationType === 'Money') {
        if (!isset($data['amount']) || empty($data['amount'])) {
            http_response_code(400);
            sendJsonResponse(array("status" => "failed", "message" => "Amount is required for Money donations"));
        }
        $amount = floatval($data['amount']);
        if ($amount <= 0) {
            http_response_code(400);
            sendJsonResponse(array("status" => "failed", "message" => "Amount must be greater than 0"));
        }
    } else {
        // Food or Medical
        if (!isset($data['description']) || empty(trim($data['description']))) {
            http_response_code(400);
            sendJsonResponse(array("status" => "failed", "message" => "Description is required for Food/Medical donations"));
        }
        $description = trim($data['description']);
    }
    
    // Escape strings
    $petId = $conn->real_escape_string($petId);
    $userId = $conn->real_escape_string($userId);
    $donationType = $conn->real_escape_string($donationType);
    if ($description) {
        $description = $conn->real_escape_string($description);
    }
    
    // Insert donation
    if ($donationType === 'Money') {
        $sql = "INSERT INTO `tbl_donations` (`pet_id`, `user_id`, `donation_type`, `amount`) 
                VALUES ('$petId', '$userId', '$donationType', '$amount')";
    } else {
        $sql = "INSERT INTO `tbl_donations` (`pet_id`, `user_id`, `donation_type`, `description`) 
                VALUES ('$petId', '$userId', '$donationType', '$description')";
    }
    
    if ($conn->query($sql) === TRUE) {
        sendJsonResponse(array(
            "status" => "success",
            "message" => "Donation submitted successfully"
        ));
    } else {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Failed to submit donation: " . $conn->error));
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

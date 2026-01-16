<?php
// Get donations made by a user
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
    
    // Get user_id from query or POST
    $userId = isset($_GET['user_id']) ? trim($_GET['user_id']) : (isset($_POST['user_id']) ? trim($_POST['user_id']) : null);
    
    if (!$userId) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "User ID is required"));
    }
    
    $userId = $conn->real_escape_string($userId);
    
    // Get donations with pet information
    $sql = "SELECT d.*, p.pet_name, p.pet_type, p.image_paths 
            FROM `tbl_donations` d 
            LEFT JOIN `tbl_pets` p ON d.pet_id = p.pet_id 
            WHERE d.`user_id` = '$userId' 
            ORDER BY d.`donation_date` DESC";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        http_response_code(500);
        sendJsonResponse(array("status" => "failed", "message" => "Database query error: " . $conn->error));
    }
    
    $donations = array();
    
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $donationData = array(
                "donation_id" => $row['donation_id'],
                "pet_id" => $row['pet_id'],
                "pet_name" => $row['pet_name'],
                "pet_type" => $row['pet_type'],
                "donation_type" => $row['donation_type'],
                "amount" => isset($row['amount']) ? floatval($row['amount']) : null,
                "description" => isset($row['description']) ? $row['description'] : null,
                "donation_date" => $row['donation_date']
            );
            
            $donations[] = $donationData;
        }
    }
    
    sendJsonResponse(array(
        "status" => "success",
        "message" => "Donations retrieved successfully",
        "data" => $donations,
        "count" => count($donations)
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

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
    if ($_SERVER['REQUEST_METHOD'] == 'POST') {
        if (!isset($_POST['email']) || !isset($_POST['password'])) {
            http_response_code(400);
            sendJsonResponse(array('status' => 'failed', 'message' => 'Bad Request'));
        }
        
        $email = trim($_POST['email']);
        $password = $_POST['password'];
        $hashedpassword = sha1($password);
        
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
        
        // Try both column name patterns
        $sqllogin = "SELECT * FROM `tbl_users` WHERE `email` = '$email' AND `password` = '$hashedpassword'";
        $result = $conn->query($sqllogin);
        
        if (!$result) {
            // Try with user_email and user_password
            $sqllogin = "SELECT * FROM `tbl_users` WHERE `user_email` = '$email' AND `user_password` = '$hashedpassword'";
            $result = $conn->query($sqllogin);
            if (!$result) {
                sendJsonResponse(array('status' => 'failed', 'message' => 'Database query error: ' . $conn->error));
            }
        }
        
        if ($result->num_rows > 0) {
            $userdata = array();
            while ($row = $result->fetch_assoc()) {
                $userdata[] = $row;
            }
            sendJsonResponse(array('status' => 'success', 'message' => 'Login successful', 'data' => $userdata[0]));
        } else {
            sendJsonResponse(array('status' => 'failed', 'message' => 'Invalid email or password', 'data' => null));
        }
    } else {
        http_response_code(405);
        sendJsonResponse(array('status' => 'failed', 'message' => 'Method Not Allowed'));
    }
} catch (Exception $e) {
    http_response_code(500);
    sendJsonResponse(array("status" => "failed", "message" => "Server error: " . $e->getMessage()));
} catch (Error $e) {
    http_response_code(500);
    sendJsonResponse(array("status" => "failed", "message" => "Fatal error: " . $e->getMessage()));
}
?>

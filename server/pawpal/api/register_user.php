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

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        sendJsonResponse(array("status" => "failed", "message" => "Method Not Allowed"));
    }
    
    if (!isset($_POST['email']) || !isset($_POST['password']) || !isset($_POST['name']) || !isset($_POST['phone'])) {
        http_response_code(400);
        sendJsonResponse(array("status" => "failed", "message" => "Bad Request - All fields are required"));
    }
    
    $name = trim($_POST['name']);
    $email = trim($_POST['email']);
    $password = $_POST['password'];
    $phone = trim($_POST['phone']);
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        sendJsonResponse(array("status" => "failed", "message" => "Invalid email format"));
    }
    
    $hashedpassword = sha1($password);
    
    // Check what columns exist - try 'email' first (most common)
    $sqlcheckmail = "SELECT * FROM tbl_users WHERE email = '$email'";
    $result = $conn->query($sqlcheckmail);
    
    if (!$result) {
        // If 'email' doesn't work, try 'user_email'
        $sqlcheckmail = "SELECT * FROM tbl_users WHERE user_email = '$email'";
        $result = $conn->query($sqlcheckmail);
        if (!$result) {
            sendJsonResponse(array('status' => 'failed', 'message' => 'Database query error: ' . $conn->error));
        }
        // Use user_email and user_password
        $emailCol = 'user_email';
        $passwordCol = 'user_password';
    } else {
        // Use email and password
        $emailCol = 'email';
        $passwordCol = 'password';
    }
    
    if ($result->num_rows > 0) {
        sendJsonResponse(array('status' => 'failed', 'message' => 'Email already registered'));
    }
    
    // Reorder user_id sequentially if there are gaps
    $reorderResult = $conn->query("SELECT user_id FROM tbl_users ORDER BY user_id ASC");
    if ($reorderResult && $reorderResult->num_rows > 0) {
        $users = $reorderResult->fetch_all(MYSQLI_ASSOC);
        $expectedId = 1;
        $needsReorder = false;
        
        // Check if reordering is needed
        foreach ($users as $user) {
            if ($user['user_id'] != $expectedId) {
                $needsReorder = true;
                break;
            }
            $expectedId++;
        }
        
        // Reorder if needed
        if ($needsReorder) {
            // Step 1: Set all user_ids to negative values to avoid conflicts
            $tempId = -1;
            foreach ($users as $user) {
                $oldId = $user['user_id'];
                $conn->query("UPDATE tbl_users SET user_id = $tempId WHERE user_id = $oldId");
                $conn->query("UPDATE tbl_pets SET user_id = $tempId WHERE user_id = $oldId");
                $tempId--;
            }
            
            // Step 2: Set user_ids to sequential positive values
            $newId = 1;
            $tempId = -1;
            foreach ($users as $user) {
                $conn->query("UPDATE tbl_users SET user_id = $newId WHERE user_id = $tempId");
                $conn->query("UPDATE tbl_pets SET user_id = $newId WHERE user_id = $tempId");
                $newId++;
                $tempId--;
            }
            
            // Reset AUTO_INCREMENT
            $nextId = count($users) + 1;
            $conn->query("ALTER TABLE tbl_users AUTO_INCREMENT = $nextId");
        }
    } else {
        // Check if table is empty and reset AUTO_INCREMENT to 1
        $countResult = $conn->query("SELECT COUNT(*) as count FROM tbl_users");
        if ($countResult) {
            $countRow = $countResult->fetch_assoc();
            if ($countRow['count'] == 0) {
                // Reset AUTO_INCREMENT to 1 when table is empty
                $resetAutoIncrement = "ALTER TABLE tbl_users AUTO_INCREMENT = 1";
                $conn->query($resetAutoIncrement);
            }
        }
    }
    
    // Get current timestamp
    $currentTimestamp = date('Y-m-d H:i:s');
    
    // Try to detect registration date column name
    $regDateCol = null;
    $checkCols = $conn->query("SHOW COLUMNS FROM tbl_users LIKE '%reg%'");
    if ($checkCols && $checkCols->num_rows > 0) {
        $colRow = $checkCols->fetch_assoc();
        $regDateCol = $colRow['Field'];
    } else {
        // Try common column names
        $commonNames = ['user_regdate', 'regdate', 'registration_date', 'created_at', 'date_registered'];
        foreach ($commonNames as $colName) {
            $testCol = $conn->query("SHOW COLUMNS FROM tbl_users LIKE '$colName'");
            if ($testCol && $testCol->num_rows > 0) {
                $regDateCol = $colName;
                break;
            }
        }
    }
    
    // Build INSERT statement with or without registration date
    if ($regDateCol) {
        $sqlregister = "INSERT INTO `tbl_users`(`name`, `$emailCol`, `$passwordCol`, `phone`, `$regDateCol`) VALUES ('$name','$email','$hashedpassword','$phone','$currentTimestamp')";
    } else {
        // If no registration date column found, insert without it
        $sqlregister = "INSERT INTO `tbl_users`(`name`, `$emailCol`, `$passwordCol`, `phone`) VALUES ('$name','$email','$hashedpassword','$phone')";
    }
    
    if ($conn->query($sqlregister) === TRUE) {
        sendJsonResponse(array('status' => 'success', 'message' => 'User registered successfully'));
    } else {
        sendJsonResponse(array('status' => 'failed', 'message' => 'Registration failed: ' . $conn->error));
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

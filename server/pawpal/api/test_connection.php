<?php
// Test database connection script
// Access this file via browser: http://YOUR_SERVER_IP/pawpal/api/test_connection.php

header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

require_once 'dbconnect.php';

$response = array();

if (!isset($conn) || !$conn) {
    $response['status'] = 'failed';
    $response['message'] = 'Database connection failed';
    $response['details'] = 'Could not connect to MySQL database. Please check your database configuration in dbconnect.php';
    http_response_code(500);
    echo json_encode($response);
    exit();
}

// Test 1: Check if connection is active
if ($conn->ping()) {
    $response['connection'] = 'success';
    $response['server_info'] = $conn->server_info;
    $response['host_info'] = $conn->host_info;
} else {
    $response['connection'] = 'failed';
    $response['message'] = 'Connection ping failed';
    http_response_code(500);
    echo json_encode($response);
    exit();
}

// Test 2: Check if database exists
$dbCheck = $conn->query("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$dbname'");
if ($dbCheck && $dbCheck->num_rows > 0) {
    $response['database'] = 'exists';
} else {
    $response['database'] = 'not_found';
    $response['message'] = "Database '$dbname' does not exist. Please create it first.";
    http_response_code(404);
    echo json_encode($response);
    exit();
}

// Test 3: Check if tables exist
$tables = array('tbl_users', 'tbl_pets');
$existingTables = array();
$missingTables = array();

foreach ($tables as $table) {
    $tableCheck = $conn->query("SHOW TABLES LIKE '$table'");
    if ($tableCheck && $tableCheck->num_rows > 0) {
        $existingTables[] = $table;
        
        // Get row count for each table
        $countResult = $conn->query("SELECT COUNT(*) as count FROM $table");
        if ($countResult) {
            $countRow = $countResult->fetch_assoc();
            $response['table_counts'][$table] = $countRow['count'];
        }
    } else {
        $missingTables[] = $table;
    }
}

$response['tables'] = array(
    'existing' => $existingTables,
    'missing' => $missingTables
);

// Test 4: Check table structure
if (in_array('tbl_users', $existingTables)) {
    $columns = $conn->query("SHOW COLUMNS FROM tbl_users");
    $userColumns = array();
    while ($row = $columns->fetch_assoc()) {
        $userColumns[] = $row['Field'];
    }
    $response['tbl_users_columns'] = $userColumns;
}

if (in_array('tbl_pets', $existingTables)) {
    $columns = $conn->query("SHOW COLUMNS FROM tbl_pets");
    $petColumns = array();
    while ($row = $columns->fetch_assoc()) {
        $petColumns[] = $row['Field'];
    }
    $response['tbl_pets_columns'] = $petColumns;
}

// Final response
if (empty($missingTables)) {
    $response['status'] = 'success';
    $response['message'] = 'Database connection successful. All tables exist.';
    http_response_code(200);
} else {
    $response['status'] = 'partial';
    $response['message'] = 'Database connected but some tables are missing: ' . implode(', ', $missingTables);
    http_response_code(200);
}

echo json_encode($response, JSON_PRETTY_PRINT);
$conn->close();
?>

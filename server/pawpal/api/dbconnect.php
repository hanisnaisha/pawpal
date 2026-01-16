<?php
/**
 * Database Connection File
 * 
 * This file establishes a connection to the MySQL database for the PawPal application.
 * It is included in all API endpoints that require database access.
 * 
 * Features:
 * - Creates mysqli connection with error handling
 * - Sets UTF-8 encoding for proper character support
 * - Verifies database existence before use
 * - Returns null connection on failure for error handling
 */

// Database connection configuration
// Update these values to match your MySQL server setup
$servername = "localhost";  // MySQL server address
$username = "root";          // MySQL username
$password = "";              // MySQL password (empty for default XAMPP setup)
$dbname = "pawpal_db";      // Database name

// Create MySQLi connection object
// MySQLi provides both procedural and object-oriented interfaces
$conn = new mysqli($servername, $username, $password, $dbname);

// Check if connection was successful
if ($conn->connect_error) {
    // Connection failed - store error message before setting connection to null
    // This allows API files to check for null connection and return appropriate error
    $error_message = $conn->connect_error;
    $conn = null;
    
    // Optional: Uncomment to log errors to PHP error log
    // error_log("Database connection failed: " . $error_message);
} else {
    // Connection successful - configure for proper character encoding
    // utf8mb4 supports full Unicode including emojis and special characters
    $conn->set_charset("utf8mb4");
    
    // Verify that the database actually exists
    // This prevents errors if database was deleted or not created yet
    $db_check = $conn->query("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$dbname'");
    if (!$db_check || $db_check->num_rows == 0) {
        // Database doesn't exist - close connection and set to null
        $conn->close();
        $conn = null;
        
        // Optional: Uncomment to log errors
        // error_log("Database '$dbname' does not exist");
    }
}
// Note: $conn will be available to all files that include this file
// API files should check if ($conn === null) before using the connection
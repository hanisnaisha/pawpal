<?php
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "pawpal_db";
$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    $conn = null;
}

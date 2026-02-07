<?php
header("Content-Type: application/json");

$counterFile = 'counter.json';
$logFile = '/volume1/web_logs/visitors.log';

// Initialize counter file if missing
if (!file_exists($counterFile)) {
    file_put_contents($counterFile, json_encode(["visits" => 0]));
}

// Read and increment counter
$data = json_decode(file_get_contents($counterFile), true);
$data["visits"]++;
file_put_contents($counterFile, json_encode($data));

// Capture visitor IP
$ip = $_SERVER['REMOTE_ADDR'];

// Append to log file
$entry = date("Y-m-d H:i:s") . " - " . $ip . "\n";
file_put_contents($logFile, $entry, FILE_APPEND);

// Return updated count
echo json_encode($data);
?>

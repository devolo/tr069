<?php
if (!isset($_SERVER['PHP_AUTH_USER'])) {
    header('WWW-Authenticate: Basic realm="Jonas Realm"');
    header('HTTP/1.0 401 Unauthorized');
    echo 'User pressed Cancel';
    exit;
} else {
    echo "<p>Hello {$_SERVER['PHP_AUTH_USER']}.</p>";
    echo "<p>You entered {$_SERVER['PHP_AUTH_PW']} as you password.</p>";
}

$target_path = "/var/www/html/protected/";
$target_path = $target_path . basename( $_FILES['uploadedfile']['name']);

echo "Source=" .        $_FILES['uploadedfile']['name'] . "<br />";
echo "Destination=" .   $destination_path . "<br />";
echo "Target path=" .   $target_path . "<br />";
echo "Size=" .          $_FILES['uploadedfile']['size'] . "<br />";

if(move_uploaded_file($_FILES['uploadedfile']['tmp_name'], $target_path)) {
echo "The file ".  basename( $_FILES['uploadedfile']['name']).
" has been uploaded";
} else{
echo "There was an error uploading the file, please try again!";
}

echo 'Debugging:';
print_r($_FILES);

print "</pre>";

header("Location: ..");
die();
?>
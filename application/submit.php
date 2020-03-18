<?php session_start();

// echo session_status();
// echo session_id();

require '/home/ubuntu/vendor/autoload.php';
include "/home/ubuntu/dbinfo.inc";

use Aws\S3\S3Client;
use Aws\DynamoDb\DynamoDbClient;
use Aws\S3\Exception\S3Exception;
use Aws\Exception\AwsException;

if (session_status() === PHP_SESSION_ACTIVE && !empty($_POST['email']))

{
    $useremail = $_POST['email'];
    $userphone = $_POST['phone'];
    // User uploaded files from index.php
    // https://www.php.net/manual/en/features.file-upload.post-method.php
    $filename = $_FILES["userfile"]["name"];

    // Bucket Names to store raw and processed image.
    $s3rawbucket = "cpooja";
    $s3processedbucket = "cpoojaresized";
    $uploaddir = '/home/ubuntu/uploads/';

    // Replacing spaces in filenames with underscore.
    $key =  str_replace(' ', '_', $filename);
    $unique_id_key = $useremail.'/'.$key;

    $uploadfile = $uploaddir . basename($key);
    $processedfile = $uploaddir . basename($key);

    // Verifying MD5sum of the file uploaded
    // $test = $_FILES['userfile']['tmp_name'];
    // $output = shell_exec("md5sum $test");
    // echo "<pre>$output</pre>";

    if (move_uploaded_file($_FILES['userfile']['tmp_name'], $uploadfile)) {
            // Verifying MD5sum of the file moved.
            $output = shell_exec("md5sum $uploadfile");
            // echo "File is valid, and was successfully uploaded. -> $output";

    } else {
            echo "Upload failed";
            echo '<pre>Here is some more debugging info:';
            print_r($_FILES);
            print "</pre>";
    }

    //Create a S3Client 
    $s3 = new S3Client([
        'version' => 'latest',
        'region'  => 'us-east-1'
    ]);

    $dynamodb = new DynamoDbClient([
        'version' => 'latest',
        'region'  => 'us-east-1'
    ]);

    # Generating a unique uuid to use for this transaction.
    $receipt = uniqid(); 
    // echo "Initiating file upload to bucket: $s3RawBucket with Key: $key and SourceFile: $uploadfile";
    try {
        // Upload data.
        $result = $s3->putObject([
            'Bucket'       => $s3rawbucket,
            'Key'          => $unique_id_key,
            'SourceFile'   => $uploadfile,
            'ACL'          => 'public-read',
            'Metadata'     => [ 'receipt' => $receipt ]
        ]);

        // Store the Raw Object URL to put in Dynamodb.
        $s3rawurl = $result['ObjectURL'] . PHP_EOL;

    } catch (S3Exception $e) {
        echo $e->getMessage() . PHP_EOL;
    }

    // https://docs.aws.amazon.com/code-samples/latest/catalog/php-rds-DescribeInstance.php.html
    try
    {
        $email = $useremail;
        $phone = $userphone;
        $s3rawurl = $s3rawurl;
        $filename = $key;
        $s3finishedurl = 'NA';
        $status = false;
        $issubscribed = false;

        $tableName = 'Records-cpooja';

        // echo "# Populating Items to $tableName...\n";
        $response = $dynamodb->putItem([
            'TableName' => $tableName,
            'Item' => [
                'Receipt'      => [ 'S'     => $receipt], // Primary Key
                'Email'   => [ 'S'     => $email ],
                'Phone'    => [ 'S'     => $phone ],
                'Filename'   => [ 'S'     => $filename ],
                'S3rawurl' => [ 'S' => $s3rawurl],
                'S3finishedurl'   => [ 'S'     => $s3finishedurl ],
                'Status' => [ 'BOOL' => $status],
                'Issubscribed' => [ 'BOOL' => $issubscribed],
            ]
        ]);

        // echo "Item populated: {$response['Item']['email']['S']}\n";
        sleep(1);
        
    } catch (AwsException $e) {
        echo $e->getMessage();
        echo "\n";
    }

    echo "
    <html>
        <head>
            <meta charset=\"utf-8\">
            <title>cpooja - MP2 Final Project</title>
            <link href=\"/css/stylesheet.css\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />
        </head>
        <body>
            <br><br><br>
            <div id=\"divForm\" name=\"divForm\" align=\"center\" style=\"border:1px solid red\">
                <h1>Image processed and Uploaded</h1>

                <form enctype=\"multipart/form-data\" action=\"gallery.php\" method=\"POST\">
                    <input type=\"submit\" value=\"View Gallery\" class=\"myButton\">
                    <input type=\"hidden\" name=\"email\" value=\"$useremail\">
                </form>
                <br><br><br>
            </div>
        </body>
    </html>
    ";
}
else{
    echo "Session not Set, please Visit index.php";
    header("Location: index.php");
}

?>

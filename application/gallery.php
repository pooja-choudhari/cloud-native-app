<html>
<title>cpooja - MP2 Final Project</title>
    <head>
        <link rel="stylesheet" href="css/stylesheet.css">
    </head>
    <body>

<?php session_start();

require '/home/ubuntu/vendor/autoload.php';
include "/home/ubuntu/dbinfo.inc";

use Aws\S3\S3Client;
use Aws\Rds\RdsClient;
use Aws\S3\Exception\S3Exception;
use Aws\Exception\AwsException;
use Aws\DynamoDb\Exception\DynamoDbException;


if (session_status() === PHP_SESSION_ACTIVE)
{
    $useremail = $_POST['email'];

    $sdk = new Aws\Sdk([
        'region'   => 'us-east-1',
        'version'  => 'latest'
    ]);

    $dynamodb = $sdk->createDynamoDb();
    $tableName = 'Records-cpooja';
    // https://docs.aws.amazon.com/code-samples/latest/catalog/php-dynamodb-Scan_SerialScan.php.html
    $params = [
        'TableName' => $tableName,
        'ExpressionAttributeValues' => [ ':Email' => ['S' => $useremail] ],
        'FilterExpression' => 'contains (Email, :Email)',
        'Limit' => 100
    ];

    echo '
    <div align="center" style="border:1px solid red">
        <br><br>
        <form enctype="multipart/form-data" action="index.php" method="POST">
        <input type="submit" value="Home" class="myButton">
        </form>
    </div>';

    // Execute scan operations until the entire table is scanned
    $count = 0;
    try
    {
        do {
            $response = $dynamodb->scan ( $params );
            $items = $response->get ( 'Items' );
            $count = $count + count ( $items );
            
            echo '<div id="divForm" name="divForm" align="center">';
            if ($count > 0 )
            {
                if (!$tbl_header)
                {
                    echo '
                    <h1>Displaying Gallery</h1>
                    <p>Note: Images may still be under processing, please wait for notification or check back later. </p>
                        <table>
                            <tr><th>Image Thumbnail</th></tr>';
                        $tbl_header=True;
                }

                // Do something with the $items
                foreach ( $items as $item )
                {
                    if ($item['S3finishedurl']['S'] != 'NA')
                    {
                        echo
                        '<tr>
                            <td><img src=' .$item['S3finishedurl']['S']. ' ></td>
                            <td>'. $item['Filename']['S']. '</td>
                        </tr>';
                    }
                }
                echo '</div></table>';
            }
            else{
                echo '<h1>No Records Found. '.$useremail.' </h1></div>';
                break;
            }

            // Set ExclusiveStartKey parameters for next scan
            $params ['ExclusiveStartKey'] = $response ['LastEvaluatedKey'];
            } while ( $params ['ExclusiveStartKey'] );

            // echo "{$tableName} table scanned completely. {$count} items found.\n";

    } catch (AwsException $e) {
        echo $e->getMessage();
        echo "\n";
    }
}

else{
    echo "Session not Set, please Visit index.php";
    header("Location: index.php");
}


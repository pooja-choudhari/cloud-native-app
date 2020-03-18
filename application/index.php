
<html>
<title>cpooja - MP2 Final Project</title>
    <head>
        <link rel="stylesheet" href="css/stylesheet.css">
    </head>
    <body>
    
    <br><br><br>
    <div id="divForm" name="divForm" align="center" style="border:1px solid red">
        <h1>Enter Information</h1>

        <form enctype="multipart/form-data" action="submit.php" method="POST">
            <p>Name:   <input type="text" name="name" required/></p>
            <p>Email:  <input type="email" name="email" required/></p>
            <p>Number: <input type="phone" name="phone" pattern="^\+[1-9]\d{1,14}$" 
                        title="+1XXXXXXXXXX" required/></p>

            <!-- https://www.php.net/manual/en/features.file-upload.post-method.php -->
            <input type="hidden" name="MAX_FILE_SIZE" value="100000000" required/>
            <p>Send this file: <input name="userfile" type="file" accept=".png,.jpg,.jpeg" required/></p>

            <input type="submit" value="Submit" class="myButton">
        </form>
    </div>
    <br><br>
    <br><br>

    <div align="center" style="border:1px solid red">
    <h1>Retrieve Your Gallery</h1>
        <form enctype="multipart/form-data" action="gallery.php" method="POST">
            <p>Email: <input type="email" name="email" required/></p>
            <input type="submit" value="Submit" class="myButton">
        </form>
    </div>

</body>
</html>
#!/bin/bash

# Prompt for MySQL root password
read -sp "Enter a password for MySQL root user: " ROOT_PASS
echo

# Prompt for phpMyAdmin user password
read -sp "Enter a password for phpMyAdmin user: " PHPMYADMIN_PASS
echo

# Update the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install Apache
echo "Installing Apache..."
sudo apt install apache2 -y

# Install MySQL
echo "Installing MySQL..."
sudo apt install mysql-server -y

# Configure MySQL root user password
echo "Setting MySQL root password..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PASS'; FLUSH PRIVILEGES;"

# Install PHP and necessary extensions
echo "Installing PHP and extensions..."
sudo apt install php libapache2-mod-php php-mysql -y

# Restart Apache to load PHP module
echo "Restarting Apache..."
sudo systemctl restart apache2

# Set up MySQL database
DB_NAME="testdb"
DB_USER="testuser"
DB_PASS="testpassword"

echo "Creating MySQL database and user..."
sudo mysql -u root -p$ROOT_PASS -e "CREATE DATABASE $DB_NAME;"
sudo mysql -u root -p$ROOT_PASS -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -u root -p$ROOT_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -u root -p$ROOT_PASS -e "FLUSH PRIVILEGES;"

# Create a test table and populate it with sample data
echo "Creating test table and inserting sample data..."
sudo mysql -u root -p$ROOT_PASS $DB_NAME <<EOF
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);
INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com'), ('Jane Doe', 'jane@example.com');
EOF

# Set up PHP script to display data
PHP_FILE="/var/www/html/index.php"

echo "Creating PHP file to display MySQL data..."
sudo bash -c "cat > $PHP_FILE" <<EOL
<!DOCTYPE html>
<html>
<head>
    <title>MySQL Database Display</title>
</head>
<body>
    <h1>Users in Database</h1>
    <?php
    \$servername = "localhost";
    \$username = "$DB_USER";
    \$password = "$DB_PASS";
    \$dbname = "$DB_NAME";

    // Create connection
    \$conn = new mysqli(\$servername, \$username, \$password, \$dbname);

    // Check connection
    if (\$conn->connect_error) {
        die("Connection failed: " . \$conn->connect_error);
    }

    \$sql = "SELECT id, name, email FROM users";
    \$result = \$conn->query(\$sql);

    if (\$result->num_rows > 0) {
        echo "<table border='1'><tr><th>ID</th><th>Name</th><th>Email</th></tr>";
        while (\$row = \$result->fetch_assoc()) {
            echo "<tr><td>" . \$row["id"]. "</td><td>" . \$row["name"]. "</td><td>" . \$row["email"]. "</td></tr>";
        }
        echo "</table>";
    } else {
        echo "0 results";
    }

    \$conn->close();
    ?>
</body>
</html>
EOL

# Adjust permissions
echo "Adjusting permissions..."
sudo chmod 644 $PHP_FILE
sudo chown www-data:www-data $PHP_FILE

# Install phpMyAdmin
echo "Installing phpMyAdmin..."
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PHPMYADMIN_PASS"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $ROOT_PASS"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PHPMYADMIN_PASS"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt install phpmyadmin -y

# Configure phpMyAdmin with Apache
echo "Configuring phpMyAdmin with Apache..."
sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

# Restart Apache
echo "Restarting Apache to apply changes..."
sudo systemctl restart apache2

echo "LAMP setup complete."
echo "Visit http://your_server_ip to view the MySQL data."
echo "Visit http://your_server_ip/phpmyadmin to manage the database."
echo "Log in to phpMyAdmin with username: root and password: $ROOT_PASS"


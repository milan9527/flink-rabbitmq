#!/bin/bash

# MySQL connection details
MYSQL_HOST="mysql8.c7b8fns5un9o.us-east-1.rds.amazonaws.com"
MYSQL_USER="admin"
MYSQL_PASS="wAr16dk7"
MYSQL_DB="test"

# Function to insert a new user
insert_user() {
    local name=$1
    local email=$2
    
    echo "Inserting user: $name, $email"
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "INSERT INTO users (name, email) VALUES ('$name', '$email');"
    
    if [ $? -eq 0 ]; then
        echo "User inserted successfully"
    else
        echo "Failed to insert user"
    fi
}

# Function to update a user
update_user() {
    local id=$1
    local name=$2
    
    echo "Updating user ID $id to name: $name"
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "UPDATE users SET name='$name' WHERE id=$id;"
    
    if [ $? -eq 0 ]; then
        echo "User updated successfully"
    else
        echo "Failed to update user"
    fi
}

# Function to delete a user
delete_user() {
    local id=$1
    
    echo "Deleting user ID $id"
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "DELETE FROM users WHERE id=$id;"
    
    if [ $? -eq 0 ]; then
        echo "User deleted successfully"
    else
        echo "Failed to delete user"
    fi
}

# Function to list all users
list_users() {
    echo "Listing all users:"
    mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "SELECT * FROM users;"
}

# Automated test sequence
echo "Starting automated MySQL test sequence..."

# List current users
echo "Current users in database:"
list_users

# Insert new test users
echo -e "\n--- INSERTING TEST USERS ---"
insert_user "John Automated" "john.auto@example.com"
insert_user "Jane Automated" "jane.auto@example.com"
sleep 2

# List users after insertion
echo -e "\nUsers after insertion:"
list_users

# Get the ID of the first test user we just inserted
USER_ID=$(mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -se "SELECT id FROM users WHERE email='john.auto@example.com' ORDER BY id DESC LIMIT 1;")

# Update the user
echo -e "\n--- UPDATING TEST USER ---"
if [ ! -z "$USER_ID" ]; then
    update_user $USER_ID "John Updated"
    sleep 2
    
    # List users after update
    echo -e "\nUsers after update:"
    list_users
    
    # Delete the user
    echo -e "\n--- DELETING TEST USER ---"
    delete_user $USER_ID
    sleep 2
    
    # List users after deletion
    echo -e "\nUsers after deletion:"
    list_users
else
    echo "Could not find test user to update/delete"
fi

echo -e "\nAutomated MySQL test sequence completed."

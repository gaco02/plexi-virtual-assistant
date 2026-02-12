import pandas as pd
import mysql.connector

# Database Configuration (Modify as needed)
DB_HOST = "localhost"
DB_USER = "your_username"
DB_PASSWORD = "your_password"
DB_NAME = "vancouver_restaurants"

# File Path (Change if needed)
TXT_FILE_PATH = "vancouver_restaurants.txt"

# Read the TXT file (Modify delimiter if needed)
df = pd.read_csv(TXT_FILE_PATH, delimiter=",", names=["Name", "Address", "Website", "Description", "Type", "Cuisine", "Hours", "Price Range"])

# Connect to MySQL
conn = mysql.connector.connect(
    host=DB_HOST,
    user=DB_USER,
    password=DB_PASSWORD
)
cursor = conn.cursor()

# Create Database (if not exists)
cursor.execute(f"CREATE DATABASE IF NOT EXISTS {DB_NAME}")
cursor.execute(f"USE {DB_NAME}")

# Create Table
cursor.execute("""
    CREATE TABLE IF NOT EXISTS restaurants (
        id INT AUTO_INCREMENT PRIMARY KEY,
        Name VARCHAR(255),
        Address TEXT,
        Website VARCHAR(255),
        Description TEXT,
        Type VARCHAR(100),
        Cuisine VARCHAR(100),
        Hours TEXT,
        Price_Range VARCHAR(50)
    )
""")

# Insert Data into MySQL
for _, row in df.iterrows():
    cursor.execute("""
        INSERT INTO restaurants (Name, Address, Website, Description, Type, Cuisine, Hours, Price_Range) 
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, tuple(row))

# Commit and Close Connection
conn.commit()
cursor.close()
conn.close()

print("Data successfully inserted into MySQL!")
import pyrebase

# Replace with your Firebase project config
firebaseConfig = {
    "apiKey": "AIzaSyCB6lVGdsQ2Dis5z5WVMN6Eex8eUgFQ5N4",
    "authDomain": "virtual-assistant-app-f7f1d.firebaseapp.com",
    "databaseURL": "https://virtual-assistant-app-f7f1d.firebaseio.com",
    "projectId": "virtual-assistant-app-f7f1d",
    "storageBucket": "virtual-assistant-app-f7f1d.firebasestorage.app",
    "messagingSenderId": "934776140552",
    "appId": "1:934776140552:web:ff4ffc263f250b4b8c32bd"
}

# firebaseConfig = {
#   apiKey: "AIzaSyCB6lVGdsQ2Dis5z5WVMN6Eex8eUgFQ5N4",
#   authDomain: "virtual-assistant-app-f7f1d.firebaseapp.com",
#   projectId: "virtual-assistant-app-f7f1d",
#   storageBucket: "virtual-assistant-app-f7f1d.firebasestorage.app",
#   messagingSenderId: "934776140552",
#   appId: "1:934776140552:web:ff4ffc263f250b4b8c32bd",
#   measurementId: "G-8X1V12T513"
# };




firebase = pyrebase.initialize_app(firebaseConfig)
auth = firebase.auth()

# Sign in with email/password
email = "test.osvaldo30@gmail.com"
password = "Osvaldo9"

user = auth.sign_in_with_email_and_password(email, password)
id_token = user["idToken"]  # This is your Firebase ID token

print("ID Token:", id_token)

# Example cURL usage:
# curl -X GET "https://yourapi.com/protected"
#      -H "Authorization: Bearer <YOUR_ID_TOKEN>"
# 💬 Flutter Chat Application
A real-time messaging application built with Flutter, Supabase, and Firebase. The app provides one-to-one and group messaging, media sharing, voice messages, location sharing, push notifications, and additional chat features.
## ✨ Features
### 🔐 Authentication & User Profile
- User registration and login
- User profile creation and management
- Profile picture, display name, and bio
- Online and offline status
### 💬 Real-Time Messaging
- One-to-one real-time text messaging
- Sent and read message indicators
- Message timestamps and unread counts
- Last message preview in the conversation list
- Reply to messages with quoted previews
- Edit and delete messages
- Delete messages for yourself or everyone
- Forward messages
- Message selection and management

### 🎤 Voice Messages
- Record and send voice messages
- Play and pause audio messages
- Audio playback progress
- Voice message duration display
- Playback controls
### 👥 Group Chat
- Create group conversations
- Add and remove group members
- Group name and profile image
- Group administration and member management
- Real-time group messaging
- Sender name identification in group conversations
- Share images and voice messages in groups
### 📎 Media & File Sharing
- Share images and documents
- View shared media and files
- Access shared media and documents from conversations
- Emoji support
### 📍 Location Sharing
- Share current location
- Send map links in conversations
- Share live location
### 🔔 Push Notifications
- Firebase Cloud Messaging (FCM) integration
- Notifications for new messages
- Device token management
### 🔎 Search & Chat Management
- Search conversations and contacts
- Search messages
- View conversation details
- Manage personal profile and chat settings
### 🎨 Additional Features
- Theme customization
- AI chatbot integration
- Logout functionality
- Real-time data updates
## 🛠️ Tech Stack
| Technology | Purpose |
|---|---|
| Flutter | Cross-platform mobile application development |
| Dart | Application programming language |
| Supabase | Backend services, database, authentication, storage, and real-time functionality |
| Firebase Cloud Messaging | Push notifications |
| Riverpod | State management |
| REST APIs | Communication with backend services |
| Geolocator | Location access and tracking |
## 🏗️ Architecture
The application uses Flutter for the user interface, Riverpod for state management, and Supabase for backend functionality and real-time data synchronization. Firebase Cloud Messaging supports push notifications.
The application is organized into reusable components and feature-specific screens to support maintainability and future development.
## 🚀 Getting Started
### Prerequisites
Make sure you have the following installed:
- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- An Android emulator or physical device
- A Supabase account and project
- A Firebase project configured for the application
### Installation
**1. Clone the repository**
```bash
git clone <your-github-repository-url>
```
**2. Open the project directory**
```bash
cd chat_app
```
**3. Install dependencies**
```bash
flutter pub get
```
**4. Configure Supabase and Firebase**
- Configure your Supabase project URL and API key.
- Set up the required database tables, relationships, and Row Level Security policies.
- Configure Firebase for your Android application.
- Add the required Firebase configuration files.
- Configure Firebase Cloud Messaging and any required notification services.
Keep API secrets and private credentials out of version control.
**5. Run the application**
```bash
flutter run
```
## 🔑 Configuration
Before running the application, ensure that all required environment settings, database schemas, authentication providers, storage permissions, and Firebase services are configured correctly.
Do not commit private API keys, service account files, or other sensitive credentials to GitHub.
## 📁 Project Highlights
- Real-time one-to-one and group conversations
- Backend integration with Supabase
- Push notifications using Firebase Cloud Messaging
- Reactive state management with Riverpod
- Media, voice, and location sharing
- Reusable Flutter UI components
## 🎯 Project Objective
The objective of this project is to develop a feature-rich messaging application that demonstrates practical skills in Flutter development, backend integration, real-time communication, state management, media handling, and push notifications.
## 👩‍💻 Developer
**Meerab Shahbaz**
Flutter & Mobile Application Developer
[GitHub](https://github.com/meerab78)
*Built with Flutter and Dart.*

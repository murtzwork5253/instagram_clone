# Instagram Clone

This is a feature-rich Instagram clone built with Flutter and backed by Supabase. It aims to replicate the core functionalities of Instagram, providing a seamless and familiar user experience.

## Features

- **Authentication:** Users can sign up, log in, and log out using email and password, Google, or Twitter.
- **Feed:** A scrollable feed of posts from followed users, with support for liking, commenting, and saving posts.
- **Stories:** Users can create, view, and interact with stories that disappear after 24 hours.
- **Reels:** A dedicated screen for watching short, vertical videos.
- **User Profiles:** View user profiles, follow and unfollow users, and see their posts and stories.
- **Search:** Search for users and view their profiles.
- **Create Post:** Upload images and videos, add captions, and tag users.
- **Notifications:** Receive notifications for new followers, likes, and comments.
- **Localization:** The app supports multiple languages, including English, Spanish, and Gujarati.
- **Push Notifications:** Firebase Cloud Messaging is integrated for push notifications.

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
- A Supabase project: [https://supabase.io/](https://supabase.io/)

### Installation

1.  Clone the repo
    ```sh
    git clone https://github.com/your_username/Instagram_clone.git
    ```
2.  Install Flutter packages
    ```sh
    flutter pub get
    ```
3.  Set up your Supabase credentials. Create a `.env` file in the root of the project and add the following:
    ```
    BASE_URL=<YOUR_SUPABASE_URL>
    API_KEY=<YOUR_SUPABASE_API_KEY>
    ```
4.  Run the app
    ```sh
    flutter run
    ```

## Technologies Used

- **Flutter:** The UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
- **Supabase:** The open-source Firebase alternative for building secure and scalable backends.
- **Provider:** A dependency injection system for Flutter that allows you to provide a value to a widget and its descendants.
- **Firebase Cloud Messaging:** A cross-platform messaging solution that lets you reliably send messages at no cost.
- **Google Sign-In:** A secure authentication system that enables users to sign in with their Google account.
- **Twitter Login:** A secure and convenient way for people to log into your app or website.

## Project Structure

The project is structured as follows:

```
lib/
├── main.dart
├── config/
├── generated/
├── l10n/
├── providers/
├── screens/
└── services/
```

- **`main.dart`**: The entry point of the application.
- **`config/`**: Contains configuration files, such as constants.
- **`generated/`**: Contains generated files, such as asset paths.
- **`l10n/`**: Contains localization files for different languages.
- **`providers/`**: Contains the application's state management logic using Riverpod and Provider.
- **`screens/`**: Contains the different screens of the application, such as the home screen, search screen, and profile screen.
- **`services/`**: Contains the application's business logic, such as interacting with Supabase and other third-party services.
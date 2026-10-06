# LibraryPlus

LibraryPlus is a Flutter-based library management application designed for university or campus library operations. It supports both students and librarians with a seamless experience for browsing books, reserving titles, booking study seats, and managing attendance through a modern mobile-style interface.

## Overview

The app combines library services into a single platform:

- Student authentication and role-based access
- Book discovery and reservation workflow
- Seat booking with availability status and scheduling
- Notifications for upcoming bookings and reservation updates
- Librarian-side management tools for library operations
- QR-based check-in flow for seat bookings and library access

## Key Features

### Student Experience

- Personalized home dashboard
- Book catalog and reservation requests
- Seat availability overview for different library sections
- Booking confirmation and cancellation handling
- Upcoming booking reminders and notifications
- QR code display for booked seats and access verification

### Librarian Experience

- Librarian dashboard and navigation shell
- Seat management and library capacity oversight
- Book inventory and reservation monitoring
- Administrative access to library operations

## Tech Stack

- Flutter
- Dart
- Supabase for authentication and backend data storage
- SharedPreferences for local session persistence
- Google Fonts for UI styling
- Flutter SVG for icons and branded assets
- QR code generation and mobile scanning support

## Project Structure

```text
.
├── lib/
│   ├── config/
│   ├── models/
│   ├── screens/
│   ├── services/
│   └── main.dart
├── assets/
├── .env.example
├── pubspec.yaml
├── README.md
└── ...
```

## Prerequisites

Before running the app, make sure you have:

- Flutter SDK installed and configured on your machine
- An IDE such as VS Code or Android Studio
- A Supabase project with the required tables and authentication enabled

## Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/chamodhlv/IT3060-Y3.S2.WE_24-library-book-seat-booking-app.git
   cd libraryplus
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Create a local environment file by copying the template:

   ```bash
   copy .env.example .env
   ```

4. Update the values in `.env` with your Supabase project credentials:

   ```env
   SUPABASE_URL=your_supabase_url_here
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   ```

5. Run the app:

   ```bash
   flutter run
   ```

## Environment Notes

This project reads Supabase configuration values from the `.env` file at runtime. If a `.env` file is not present, the app will still start only if values are provided through Flutter environment variables or the required backend services are already configured.

## Usage

- Sign in as a student or librarian depending on the account role
- Browse available books and place reservations
- Check seat availability by day and section
- Confirm bookings and view notifications
- Use the QR flow during booking check-in or verification

## Notes

This project is intended as a library booking and seat reservation application prototype, with backend data managed through Supabase. Configuration values should remain private and should not be committed to public repositories if they contain live project credentials.

# In-Class Activity 09 – Card Collection App

## Project Overview

For this activity, I continued working on my Flutter app from Activity 08. The main goal was to add folders and cards using SQLite while keeping the guest records from the previous activity.

I kept the design simple so it would be easy to add, view, edit, and delete information.

## Features

- Create and delete folders
- View the number of cards in each folder
- Add cards with a title, suit, and optional notes
- Edit and delete existing cards
- Choose between Hearts, Diamonds, Clubs, and Spades
- Display a card symbol when an image is missing
- Save data locally using SQLite
- Show a confirmation message before deleting
- Access the guest records from Activity 08

## Tools Used

- Flutter and Dart
- SQLite (sqflite)
- Visual Studio Code
- Android Emulator
- GitHub

## Database

The app uses the `fall_festival.db` database from Activity 08.

The database version was changed from 1 to 2 to support the new tables.

The main tables are:

- **guests:** Stores the guest information from Activity 08.
- **folders:** Stores folder names and IDs.
- **cards:** Stores card information and connects each card to a folder using `folder_id`.

I used `ON DELETE CASCADE` so that deleting a folder also deletes the cards belonging to that folder.

## How to Run

1. Open the Flutter project in VS Code.
2. Run `flutter pub get`.
3. Start an Android emulator.
4. Run `flutter run`.
5. Add a folder and open it to add cards.

To build the release APK, use:

`flutter build apk --release`

## Testing

I tested the app using sample folders and cards. The required test results are recorded below.

| Test | Description 
|---|---|---|
| T1 | Database upgrade and fresh installation 
| T2 | Create folders and cards 
| T3 | Edit a card and cancel another edit 
| T4 | Restart the app and check saved data 
| T5 | Delete a card and test folder cascade deletion 
| T6 | Check invalid input and missing image fallback  

## Screenshots and Evidence

The `evidence` folder contains:

- `T1_before.png` – Guest records before the database upgrade
- `T2_cards.png` – Folders and cards after adding sample data

## What I Learned

This activity helped me understand how SQLite can be used to manage related data in a Flutter app. I also learned more about using IDs instead of names when updating or deleting records.

One important part was understanding how a database upgrade works without removing existing data. I also practiced handling user input and making sure the app displays useful messages when something goes wrong.


## References

- Flutter Documentation
- sqflite Package Documentation
- Activity 09 Lecture Notes
- [Add any AI assistance used, if applicable]

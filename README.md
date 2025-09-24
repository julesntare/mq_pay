# MQ Pay

![App Icon](assets/icon/icon.png)

MQ Pay is a modern mobile payment application built with Flutter that simplifies mobile money transactions in Rwanda. The app enables users to generate and scan USSD codes for quick payments, manage payment history, and find nearby stores that accept mobile payments.

## Features

- **QR Code Scanner**: Scan QR codes containing USSD payment codes
- **Multi-step Payment Form**: Intuitive interface for entering payment details
- **Contact Integration**: Select recipients from your phone's contact list
- **Payment History**: Track and manage your payment records
- **Store Locator**: Find nearby stores that accept MQ Pay
- **Multi-language Support**: Available in English, French, Kinyarwanda, and Swahili
- **Dark/Light Theme**: Toggle between light and dark modes
- **Offline Storage**: Uses SharedPreferences for local data storage
- **Firebase Integration**: Cloud storage and synchronization

## Screenshots

The app features a modern, clean interface with:
- Home screen with quick payment actions
- Multi-step payment form
- QR scanner interface
- Payment history tracking
- Store management system
- Settings and preferences

## Technology Stack

- **Framework**: Flutter 3.6.1+
- **Language**: Dart
- **State Management**: Provider pattern
- **Local Storage**: SharedPreferences
- **Backend**: Firebase (Firestore, Core)
- **Navigation**: MaterialPageRoute
- **Internationalization**: flutter_localizations
- **QR Functionality**: qr_flutter, mobile_scanner
- **Location Services**: geolocator
- **HTTP Requests**: http package

## Prerequisites

Before running this project, ensure you have:

- Flutter SDK (3.6.1 or higher)
- Dart SDK
- Android Studio / VS Code
- Android SDK / iOS development tools
- Firebase account (for backend services)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/julesntare/mq_pay.git
cd mq_pay
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Firestore Database
3. Download `google-services.json` (Android) and place it in `android/app/`
4. Download `GoogleService-Info.plist` (iOS) and place it in `ios/Runner/`
5. Run the Firebase CLI configuration:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

### 4. Generate Localization Files

```bash
flutter gen-l10n
```

### 5. Run the Application

For development:
```bash
flutter run
```

For release build:
```bash
flutter build apk --release
flutter build ios --release
```

## Project Structure

```
lib/
├── generated/          # Generated localization files
├── helpers/           # Utility classes and providers
│   ├── app_theme.dart
│   ├── launcher.dart
│   ├── localProvider.dart
│   └── theme_provider.dart
├── l10n/              # Localization files
├── models/            # Data models
│   ├── store.dart
│   └── ussd_record.dart
├── screens/           # UI screens
│   ├── home.dart
│   ├── qr_scanner_screen.dart
│   ├── settings.dart
│   ├── store_*.dart
│   └── ussd_records_screen.dart
├── services/          # Business logic and API calls
│   ├── store_service.dart
│   └── ussd_record_service.dart
└── main.dart          # Application entry point
```

## Configuration

### Environment Variables

Create a `.env` file in the root directory:

```
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_API_KEY=your_api_key
```

### App Configuration

The app uses several configuration files:
- `pubspec.yaml`: Dependencies and app metadata
- `analysis_options.yaml`: Dart linting rules
- `firebase.json`: Firebase configuration

## Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
4. **Follow the coding standards**:
   - Use proper Dart formatting: `dart format .`
   - Run static analysis: `flutter analyze`
   - Ensure tests pass: `flutter test`
5. **Commit your changes**
   ```bash
   git commit -m 'Add some amazing feature'
   ```
6. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Open a Pull Request**

### Code Style Guidelines

- Follow Dart style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused
- Use proper error handling

### Testing

Run tests before submitting:
```bash
flutter test
flutter test --coverage
```

## Usage

### Making a Payment

1. **Enter Amount**: Input the payment amount in RWF
2. **Add Recipient**: Enter phone number or momo code, or select from contacts
3. **Generate USSD**: App creates the appropriate USSD code
4. **Dial and Confirm**: Use the generated code to complete payment

### Scanning QR Codes

1. Tap "Scan Now" on the home screen
2. Point camera at QR code
3. App automatically processes the payment information
4. Follow prompts to complete transaction

### Managing Stores

1. Navigate to "Nearby Stores"
2. View stores on map or list view
3. Add/edit store information
4. Get directions to stores

## Localization

The app supports multiple languages:
- English (en)
- French (fr)
- Kinyarwanda (rw)
- Swahili (sw)

To add a new language:
1. Create `intl_[language_code].arb` in `lib/l10n/`
2. Add translations
3. Run `flutter gen-l10n`
4. Update supported locales in `main.dart`

## API Documentation

### USSD Code Generation

The app generates USSD codes for different mobile money services:

- **MTN Mobile Money**: `*182*1*1*[phone]*[amount]#`
- **Irembo**: `*909#`
- **Momo Code**: `*182*8*1*[code]*[amount]#`

### Firebase Collections

- `stores`: Store location and details
- `ussd_records`: Payment history and records

## Security

- Phone numbers are masked in UI and storage
- Sensitive data is encrypted
- Firebase security rules restrict data access
- Input validation prevents code injection

## Troubleshooting

### Common Issues

**Build Failures**:
```bash
flutter clean
flutter pub get
flutter run
```

**Firebase Issues**:
- Verify `google-services.json` placement
- Check Firebase project configuration
- Ensure proper dependencies in `pubspec.yaml`

**Location Permissions**:
- Add location permissions in platform-specific files
- Handle permission requests in code

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Rwanda mobile money providers for USSD standards
- Open source community for various packages

## Support

For support and questions:
- Create an [Issue](https://github.com/julesntare/mq_pay/issues)
- Check existing documentation
- Review Flutter documentation

## Changelog

### Version 1.0.0
- Initial release
- Basic payment functionality
- QR code scanning
- Store locator
- Multi-language support

---

# CPF Mobile (`cpf_mobile`)

Android & Web Flutter client for the **Circle of Peer Facilitators (CPF)**, built against [docs/API_CONTRACT.md](docs/API_CONTRACT.md).

## Documentation

- **Web Running & Serving Guide:** [docs/RUN_ON_WEB.md](docs/RUN_ON_WEB.md)
- **REST API v1 Contract:** [docs/API_CONTRACT.md](docs/API_CONTRACT.md)

## Quick Commands

### Run on Web
See [docs/RUN_ON_WEB.md](docs/RUN_ON_WEB.md) for one-time `flutter create --platforms=web .` setup and CORS notes:
```powershell
flutter run -d chrome --web-port=5050
```

### Build Android Debug APK
```powershell
flutter build apk --debug
```
Output APK: `build\app\outputs\flutter-apk\app-debug.apk`

### Analyze & Test
```powershell
flutter analyze
flutter test
```

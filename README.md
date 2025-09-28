# AI Assistant MVP

Piattaforma desktop multipiattaforma per integrazioni AI aziendali che combina la potenza delle API Claude con l'accesso completo ai file system locali e servizi cloud.

## 🚀 Getting Started

### Prerequisiti

- Flutter SDK 3.19.0 o superiore
- Dart 3.2.0 o superiore
- Windows 10+, macOS 10.15+, o Linux (Ubuntu 18.04+)

### Installazione

1. **Clona il repository**
   ```bash
   git clone https://github.com/your-repo/ai-assistant-mvp.git
   cd ai-assistant-mvp
   ```

2. **Installa le dipendenze**
   ```bash
   flutter pub get
   ```

3. **Abilita il supporto desktop**
   ```bash
   flutter config --enable-windows-desktop
   flutter config --enable-macos-desktop  
   flutter config --enable-linux-desktop
   ```

4. **Verifica la configurazione**
   ```bash
   flutter doctor
   ```

### Esecuzione

#### Modalità Debug
```bash
# Windows
flutter run -d windows

# macOS  
flutter run -d macos

# Linux
flutter run -d linux
```

#### Modalità Release
```bash
# Windows
flutter run -d windows --release

# macOS
flutter run -d macos --release

# Linux
flutter run -d linux --release
```

## 🏗️ Architettura

Il progetto segue i principi della **Clean Architecture** con tre layer principali:

```
lib/
├── presentation/     # UI, Widgets, Screens
├── domain/          # Business Logic, Use Cases
├── data/            # Data Sources, Repositories
└── core/            # Utilities, Constants, Theme
```

### Stack Tecnologico

- **Framework**: Flutter Desktop 3.19.0+
- **State Management**: Riverpod 2.4.9+
- **Navigation**: GoRouter 13.2.0+
- **Database**: SQLite (sqflite_common_ffi)
- **Cache**: Hive 2.2.3+
- **Network**: Dio 5.4.0+
- **Security**: Flutter Secure Storage 9.0.0+

## 🎨 Design System

L'applicazione utilizza un design system personalizzato con:

- **Colori**: Palette consistente con supporto dark/light mode
- **Typography**: Font Inter con gerarchie tipografiche definite
- **Componenti**: Widget riutilizzabili e platform-specific UI

### Temi Supportati

- **Windows**: Fluent Design System
- **macOS**: Human Interface Guidelines  
- **Linux**: Yaru Design Language
- **Fallback**: Material Design 3

## 📁 Struttura del Progetto

### Core
- `constants/` - Costanti globali dell'applicazione
- `theme/` - Tema, colori e stili
- `utils/` - Utilities e helper functions
- `exceptions/` - Custom exceptions

### Data Layer
- `datasources/local/` - Database locale e file system
- `datasources/remote/` - API services (Claude, Google)
- `models/` - Data models
- `repositories/` - Repository implementations

### Domain Layer  
- `entities/` - Business entities
- `repositories/` - Repository interfaces
- `usecases/` - Business use cases

### Presentation Layer
- `screens/` - Schermate principali
- `widgets/` - Componenti UI riutilizzabili  
- `providers/` - State management providers

## 🧪 Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Widget tests
flutter test test/widget_tests/
```

## 📦 Build

### Windows
```bash
flutter build windows --release
```

### macOS
```bash
flutter build macos --release
```

### Linux
```bash
flutter build linux --release
```

## 🔒 Sicurezza

- Gestione sicura delle API keys con Flutter Secure Storage
- Crittografia locale dei dati sensibili
- Validazione input e sanitizzazione
- Gestione sicura delle credenziali OAuth

## 🎯 Roadmap

### Milestone 1: Foundation ✅
- Setup progetto Flutter desktop
- Architettura base (Clean Architecture + Riverpod) 
- Database locale (SQLite)
- UI foundation e tema

### Milestone 2: Core Chat (In Progress)
- Integrazione Claude API
- Chat interface completa
- Message persistence
- Context management base

### Milestone 3: File System
- File scanning e indexing
- File preview widgets  
- Search functionality locale
- Pin system base

### Milestone 4: Google Integration
- OAuth 2.0 implementation
- Gmail API integration
- Google Drive API integration
- Sync e caching

### Milestone 5: Smart Features
- Smart Preview Window completa
- Pin system avanzato
- Action execution system
- File relationship mapping

### Milestone 6: Polish & Deploy
- UI/UX refinement
- Performance optimization
- Testing completo
- Build e packaging
- Documentation

## 🤝 Contributing

1. Fork il repository
2. Crea un branch per la tua feature (`git checkout -b feature/amazing-feature`)
3. Commit le tue modifiche (`git commit -m 'Add amazing feature'`)
4. Push al branch (`git push origin feature/amazing-feature`)
5. Apri una Pull Request

## 📄 License

Questo progetto è distribuito sotto licenza MIT. Vedi `LICENSE` per maggiori dettagli.

## 📞 Support

Per support e domande:
- Apri un issue su GitHub
- Invia email a support@company.com
- Consulta la documentazione wiki

---

**Sviluppato con ❤️ usando Flutter**
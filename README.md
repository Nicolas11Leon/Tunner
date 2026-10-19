# Tunner

An open-source, high-precision pitch detection, acoustic analysis, and interactive music learning platform.

---

## Overview

Tunner is an open-source initiative dedicated to democratizing music education. Learning to sing or play an instrument should be accessible, transparent, and intuitive for everyone, regardless of background or financial means.

The platform bridges the gap between precision acoustic engineering and accessible pedagogical tools. It provides real-time pitch tracking, microtonal deviation analysis, and an interactive sheet music environment designed to deconstruct complex musical passages into clear, actionable practice steps.

---

## Core Objectives

- **Democratize Music Learning:** Provide a free, accessible platform where anyone can develop pitch accuracy, rhythmic awareness, and sight-reading skills at their own pace.
- **Precision Audio Analysis:** Deliver low-latency fundamental frequency ($F_0$) estimation and fine-grained cents deviation suitable for both vocalists and instrumentalists.
- **Interactive Score Decomposition:** Break down melodies, intervals, and rhythmic subdivisions into digestible practice modules with immediate visual feedback.
- **Extensible Architecture:** Maintain a clean, modular open-source codebase ready for community contributions, MusicXML/MIDI integration, and advanced signal processing models.

---

## Key Features

- **Multi-Source Pitch Detection:** High-fidelity fundamental frequency estimation tailored for both continuous vocal performance and diverse instrument timbres.
- **Microtonal Accuracy:** Real-time cents calculation and pitch tracking against standard equal temperament ($A_4 = 440\text{ Hz}$, configurable).
- **Interactive Sheet Music Notation:** Real-time playhead tracking, dynamic measure navigation, and visual feedback on intonation and rhythm.
- **Rhythmic Guidance:** Integrated metronome with customizable tempo and sub-beat quantization.
- **Cross-Platform Delivery:** Built with Flutter to support mobile, desktop, and web environments from a single unified codebase.

---

## Technical Stack & Architecture

- **Framework:** Flutter / Dart
- **State Management:** Provider / Clean Architecture principles
- **Audio Processing:** Real-time stream recording, circular audio buffering, and time/frequency domain pitch estimation algorithms
- **Target Platforms:** Linux, Android, iOS, macOS, Windows, Web

```
tunner/
├── lib/
│   ├── data/           # Audio stream ingestion, DSP, and metronome services
│   ├── domain/         # Core musical entities, intervals, score models, and business logic
│   ├── presentation/   # Reactive UI, tuner displays, sheet music canvas, and view models
│   └── main.dart       # Application entry point and dependency wiring
└── pubspec.yaml        # Project dependencies and asset definitions
```

---

## Getting Started

### Prerequisites

- Flutter SDK (version 3.11.5 or newer)
- Dart SDK
- Operating system platform dependencies (ALSA/PulseAudio/PipeWire for Linux, Xcode for iOS/macOS, Android SDK for Android)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/Nicolas11Leon/Tunner.git
   cd Tunner
   ```

2. Fetch project dependencies:
   ```bash
   flutter pub get
   ```

3. Launch the application:
   ```bash
   flutter run
   ```

---

## Git Workflow & Contribution Guidelines

We warmly welcome community contributions, suggestions, and bug reports. To maintain stability across releases, this repository follows a protected branch model:

- The `main` branch is protected and contains stable, reviewed code. Direct pushes are disabled.
- Only repository maintainers can merge Pull Requests into `main`.
- All contributions must be submitted via feature branches and Pull Requests.

### Step-by-Step Contribution Process

1. Fork the repository on GitHub.
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/Tunner.git
   cd Tunner
   ```
3. Create a descriptive feature branch:
   ```bash
   git checkout -b feature/audio-dsp-enhancement
   ```
4. Commit your changes with clear, concise commit messages:
   ```bash
   git commit -m "feat(dsp): improve pitch detection windowing"
   ```
5. Push to your branch and open a Pull Request against the upstream `main` branch:
   ```bash
   git push origin feature/audio-dsp-enhancement
   ```

All Pull Requests are reviewed to ensure code quality, architecture consistency, and test coverage before merging.

---

## License

This project is licensed under the [MIT License](LICENSE). It is open source, free to use, study, modify, and distribute.

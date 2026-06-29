# Spectral

A Flutter showcase app demonstrating real-time audio DSP, GPU fragment shaders, and on-device AI — all wired together via Dart FFI to native C/C++ code.

---

## Features

### Live Visualizer
- Captures microphone audio in real time using **miniaudio** (C)
- Runs a **KISS FFT** (C) on each audio frame to produce a frequency spectrum
- Uploads the spectrum as a 1D texture and renders it through a custom **GLSL fragment shader** — no Flutter widgets involved in the render path
- Frame-rate locked to vsync via a `Ticker`

### Video Highlight Detection
Pick any video from the gallery and the app automatically finds the best moments:

| Signal | How |
|---|---|
| Audio energy & beats | Custom C analyzer — RMS energy + onset flux detection |
| Speech transcript | **Whisper.cpp** (C++) running on-device, loaded via FFI |
| Scene changes | Frame difference scoring via native C histogram comparison |
| Faces & expressions | **Google ML Kit** face detection on extracted frames |

Signals are weighted into a composite score per 5-second window. Overlapping candidates are pruned with non-maximum suppression. The top clips are presented in a clip editor.

### Clip Editor
- Preview each detected highlight with bounded playback (auto-stops at clip end)
- Scrub within a clip using a draggable slider
- Trim clip start/end in 1-second steps
- Reorder clips via drag-and-drop
- Long-press a clip for a per-signal score breakdown
- Export the selected clips as a single stitched `.mp4`

---

## Architecture

```
lib/
├── core/
│   ├── locator.dart       # GetIt service locator — all singletons registered here
│   └── router.dart        # GoRouter — declarative named routes
├── features/              # MVVM — one folder per screen
│   ├── home/
│   ├── visualizer/
│   ├── analysis/
│   ├── editor/
│   └── export/
├── ffi/                   # Dart FFI bindings
│   ├── spectral_ffi.dart  # miniaudio + KISS FFT
│   ├── analyzer_ffi.dart  # energy / onset / frame-diff
│   └── whisper_ffi.dart   # Whisper.cpp transcription
├── services/              # Business logic (injected via GetIt)
│   ├── ffmpeg_service.dart
│   ├── highlight_detector.dart
│   ├── face_detection_service.dart
│   └── whisper_model_service.dart
└── models/
    ├── video_segment.dart
    └── analysis_result.dart
```

**Pattern:** ViewModels are `ChangeNotifier` subclasses. Views are dumb — they use `ListenableBuilder` to observe state and call ViewModel methods on user actions. No business logic lives in the View layer.

---

## Native layer

```
android/app/src/main/cpp/
├── spectral.c / .h        # miniaudio + KISS FFT wrapper
├── analyzer.c / .h        # RMS energy, onset detection, frame diff
└── whisper_wrapper.cpp/.h # Whisper.cpp C-compatible API
```

Whisper.cpp is fetched at CMake configure time via `FetchContent`. The ggml-tiny.en model (~75 MB) is downloaded on first use to the app's documents directory.

---

## Key dependencies

| Package | Purpose |
|---|---|
| `ffmpeg_kit_flutter_new` | Audio extraction, frame extraction, clip export |
| `video_player` | In-editor clip preview |
| `google_mlkit_face_detection` | On-device face & expression scoring |
| `get_it` | Service locator / dependency injection |
| `go_router` | Declarative routing |
| `file_picker` | Gallery video selection |
| `share_plus` | Share / save exported highlight reel |
| `permission_handler` | Microphone permission (visualizer) |

---

## Running the app

```bash
flutter pub get
flutter run
```

Requires Android (minSdk 24). Whisper.cpp requires a CMake build — first build will take several minutes while the native library compiles.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Requires **Xcode 26+** and a simulator or device running **iOS/iPadOS 26+**. No external dependencies, no internet, no accounts.

```bash
# Build for simulator (CLI — must use explicit DEVELOPER_DIR)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Faro.xcodeproj -scheme Faro -sdk iphonesimulator build

# Open in Xcode (preferred for run/debug)
open Faro.xcodeproj
```

There are no tests, linting scripts, or Package.swift — the project is a pure Xcode project. Launch argument `-FaroOpenDemo` opens the demo case directly on startup (useful for UI work).

## Architecture

**MVVM-light with protocol-backed services.** No coordinator, no dependency injection container.

### Navigation root

`RootView` holds `@State private var router = AppRouter()` and injects it as `@Environment`. `AppRouter` is `@Observable`. `AppRouter.activeCase: CaseFile?` is the single switch: `nil` → `HomeView`, non-nil → `CaseContainerView`. New-case intake is a `fullScreenCover` driven by `router.showingCrisisFlow`; which view it presents depends on `router.intakeMode`:
- `.conversational` → `ChatIntakeView` (AI chat intake)
- `.guided` → `CrisisModeView` (one-question-per-screen, low-stress mode)

The mode is chosen in `EthicsNoticeView` (the "Antes de empezar" sheet from `HomeView`); `CasesListView`'s empty-state "Crear caso" defaults to `.conversational`.

`CaseContainerView` branches on `horizontalSizeClass`:
- **iPad (regular):** `NavigationSplitView` with `.listStyle(.sidebar)`, 4 grouped sections
- **iPhone (compact):** `NavigationStack` rooted at `CaseDashboardView`, `navigationDestination(for: CaseSection.self)`

### SwiftData schema

`CaseFile` is the only root model inserted into the context. Everything else is a cascade-delete child relationship. All `@Model` types must be listed in the `Schema` in `FaroApp.swift` — currently registered: `CaseFile`, `MissingPerson`, `EvidenceItem`, `TimelineEvent`, `TrustedContact`, `CaseTask`, `CaseQuestion`, `LocationRecord`, `GeneratedReport`, `PublicPoster`. Additional `@Model` types exist in the codebase (`ChatSession`, `ChatMessage`, `IntakeQuestionRecord`, `CaseFicha`) and must be added to the Schema if SwiftData doesn't infer them automatically.

```
CaseFile
 ├─ MissingPerson           (1:1)
 ├─ EvidenceItem[]          (OCR text, file data, sensitivity, validation state)
 ├─ TimelineEvent[]         (date, source, confidence, validation state)
 ├─ TrustedContact[]
 ├─ CaseTask[]
 ├─ CaseQuestion[]
 ├─ LocationRecord[]
 ├─ GeneratedReport[]
 ├─ PublicPoster[]
 ├─ IntakeQuestionRecord[]  (per-question state for chat intake flow)
 ├─ CaseFicha[]             (versioned technical reports; never auto-deleted)
 └─ ChatSession[]
      └─ ChatMessage[]
```

`CaseFile.touch()` increments `dataRevision` and marks any generated `CaseFicha` as outdated. Use `touchDocumentsOnly()` when only documents change, not case data.

### Services

`AppServices.shared` (MainActor singleton) instantiates all services at launch. Every service accessed through a protocol — never instantiate concrete types directly in views.

| Protocol | Real impl | Mock |
|---|---|---|
| `AIProcessingServiceProtocol` | `FoundationModelsAIService` | `MockAIService` |
| `CaseAIServiceProtocol` | `FoundationModelsChatAIService` | `MockChatAIService` |
| `OCRServiceProtocol` | `VisionOCRService` | `MockOCRService` |
| `SpeechTranscriptionServiceProtocol` | `SpeechFileTranscriptionService` | `MockSpeechService` |
| `CaseScoringServiceProtocol` | `CaseScoringService` | — |

Non-protocol services (no mock needed): `TimelineAnalysisService`, `PosterBuilderService`, `ReportBuilderService`, `PDFExportService`, `FichaComposerService`.

`AIServiceFactory.makeService()` and `ChatAIServiceFactory.makeService()` each select the real Foundation Models implementation or fall back to the deterministic mock at runtime based on `SystemLanguageModel.default.availability`. `AppServices` also exposes `.demoOCR` and `.demoSpeech` (always mocks) for the demo flow.

### Two AI service layers

There are two distinct AI protocols serving different parts of the app:

- **`AIProcessingServiceProtocol`** — used by `AppServices.shared.ai` for evidence classification, timeline suggestions, case summaries, and poster text. Lives in `AI/AIService.swift`.
- **`CaseAIServiceProtocol`** — used by `ChatIntakeViewModel` for the conversational intake flow: classifying user replies, extracting structured fields, suggesting next questions, generating the ficha. Lives in `AI/ChatCaseIntakeService.swift`.

Both follow the same pattern: Foundation Models polishes language; all data extraction is deterministic via `SpanishIntakeEngine` (regex + rule-based NLP in Mexican Spanish). Neither invents facts.

### AI constraint (non-negotiable)

Everything produced by any AI service enters the model as **`validationState = .pending`** and `classificationSuggestedByAI = true`. Nothing is ever committed as confirmed without explicit human review in `ValidationCenterView`. Do not bypass this when adding AI-powered features.

### Chat intake flow

`ChatIntakeView` owns the conversational intake, backed by `ChatIntakeViewModel`. The view model uses `CaseAIServiceProtocol` to process messages, extract `DetectedField` values, and advance `IntakeQuestionRecord` states. `IntakeQuestionBank` is the data-driven question set — questions have category, priority, a human-friendly phrasing, and a formal ficha label. The bank drives question ordering, not the view.

`CrisisModeView` is the alternate `.guided` intake (the "low-stress mode"): a 12-step flow (`CrisisStep` enum in `CrisisFlowViewModel`), one question per screen, directional slide animations. `goingForward: Bool` tracks direction before each `withAnimation` call; steps use `.id(viewModel.stepNumber)` + `.transition(stepTransition)`. `CrisisQuestionView` is the shared container for every step. On finish, `CrisisFlowViewModel.buildCase(in:)` creates the `CaseFile` (gaps become pending `CaseQuestion`s) and `ChatIntakeViewModel.syncStatesFromExistingCase()` later picks up those pre-filled values if the user switches to chat.

### Design system

All colors, radii, spacing, and animation presets live in `FaroTheme`. Never hardcode hex values or `CGFloat` constants in views.

Key theme tokens:
- **Colors:** `FaroTheme.night` (primary/brand), `.background`, `.surface`, `.secondaryText`, `.amber` (pending/attention), `.confirmedGreen`, `.destructive`
- **Metrics:** `.cornerRadius` (16), `.smallCornerRadius` (10), `.cardPadding` (18), `.screenPadding` (20), `.sectionSpacing` (24)
- **Animations:** `FaroTheme.springSnappy` (buttons/press), `.springSmooth` (modals/flow), `.springEntrance` (screen entrances) — use these for all `withAnimation` calls

Key View extensions and styles:
- `faroCard()` — standard card modifier (padding + surface bg + shadow)
- `faroEntrance(visible:delay:)` — staggered entrance; pattern is `@State private var appeared = false` + `.onAppear { withAnimation { appeared = true } }`
- `FaroPrimaryButtonStyle()` — large, full-width, night-colored primary action
- `FaroSecondaryButtonStyle()` — bordered secondary action
- `FaroQuietButtonStyle()` — visually silent, for "Skip" / "I don't know" actions
- `FaroCardButtonStyle()` — subtle scale on press; use on any `Button` or `NavigationLink` wrapping a card (replaces `.buttonStyle(.plain)`)
- `FaroSectionHeader` — standardized section header component with optional subtitle

### Demo case

`DemoCaseFactory.makeDemoCase(in:)` creates the Mariana López fictional case. Dates are computed relative to "yesterday" so the demo always looks fresh. It can be reset from `CaseSettingsView`. The factory must remain self-contained — no real photos, no real locations, no real names.

### Ethical filter (PosterBuilderService)

`PosterBuilderService` applies a **deterministic** exclusion filter for public posters — what gets excluded is decided by code, not by a model, and every exclusion has an explicit reason shown in `PublicPosterView`. Do not move this logic to an AI service.

### TrainingPreparationService

This service is an intentional no-op. It defines `AnonymizedCaseSchema` — the structural shape of what a future anonimized training dataset would look like — but `exportConsentGranted` is hardcoded `false` and there is no UI to activate it. Do not add export functionality without adding consent flow, full anonymization, institutional authorization, and ethics review first.

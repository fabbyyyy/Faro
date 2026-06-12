# FARO

App para iPhone y iPad construida con **Swift, SwiftUI y SwiftData**, con **IA 100 % en el dispositivo**. Desarrollada para el **Swift Challenge Fest 2026** — reto *Human-Centered AI resolviendo un ODS*.

---

## El problema

Cuando una persona desaparece, la familia entra en crisis: miedo, llamadas, capturas de WhatsApp, audios, rumores, recuerdos incompletos, datos médicos. Justo cuando más claridad se necesita, la información **se pierde, se duplica, se comparte mal o se mezcla con datos no confirmados**.

FARO convierte ese caos en un **expediente vivo, privado, validado y accionable** durante las primeras 72 horas: organiza capturas, audios, ubicaciones, testimonios y datos sueltos; separa lo confirmado de lo pendiente; y prepara materiales útiles para búsqueda, acompañamiento o denuncia.

FARO **no sustituye** a autoridades, colectivos, abogados ni protocolos oficiales. Solo estructura información, reduce carga mental, evita difusión irresponsable y protege datos sensibles.

---

## ODS que aborda

- **ODS 16 — Paz, justicia e instituciones sólidas**: documentación clara y ordenada que facilita la interacción con instituciones y colectivos de búsqueda.
- **ODS 10 — Reducción de desigualdades**: no todas las familias tienen acceso a asesoría legal o redes organizadas. FARO acerca esa capacidad de documentación a cualquier familia con un iPhone.

---

## Por qué es Human-Centered AI

La IA está **al servicio de la familia, no al centro del producto**. Esta distinción no es retórica — está codificada en cada capa de la arquitectura:

- **La IA sugiere, la persona decide.** Todo lo extraído por OCR, transcripción o modelos generativos entra al expediente como `validationState = .pending`. Nada se convierte en hecho sin validación humana explícita.
- **Estados de confianza explícitos**: `confirmado`, `pendiente`, `aproximado`, `contradictorio`, `descartado`. La interfaz marca siempre lo "Sugerido por IA · requiere revisión".
- **Crisis-first design**: una pregunta por pantalla, tipografía grande, "No lo sé todavía" y "Saltar por ahora" sin culpa. Una persona en crisis no contesta un censo.
- **Filtro ético determinista**: qué se publica y qué se protege en la ficha pública **no lo decide un modelo**; lo decide código auditável que explica cada exclusión a la familia.
- **Motor siempre visible**: la UI indica en todo momento si está activo Foundation Models o el asistente local determinista.

---

## Arquitectura de IA: modelo híbrido en dos capas

FARO no es "un chatbot con un modelo grande detrás". Es una **arquitectura modular**, donde cada componente usa la herramienta correcta:

| Capa | Protocolo | Motor real | Respaldo |
|---|---|---|---|
| Procesamiento del caso | `AIProcessingServiceProtocol` | `FoundationModelsAIService` | `MockAIService` |
| Conversación de intake | `CaseAIServiceProtocol` | `FoundationModelsChatAIService` | `MockChatAIService` |

`AIServiceFactory.makeService()` y `ChatAIServiceFactory.makeService()` eligen **Foundation Models** cuando `SystemLanguageModel.default.availability == .available`; si no, devuelven el motor local determinista. La app es **completamente funcional** en ambos casos.

### Los ocho módulos de IA

| # | Módulo | Motor | Por qué |
|---|---|---|---|
| 1 | **Intake** — entiende al usuario | Determinista (clasifica) + modelo (tono) | Clasificar "no sé / estrés / dato" debe ser predecible |
| 2 | **Formalizer** — informal → técnico | Determinista | La redacción de ficha debe ser reproducible |
| 3 | **Sensitivity** — detecta lo sensible | Determinista + sugerencia de modelo | Lo médico/privado no puede filtrarse por alucinación |
| 4 | **Timeline** — ordena y detecta huecos | Determinista | Las horas se detectan por regex; los huecos por aritmética |
| 5 | **Contradiction** — detecta conflictos | Determinista | Genera pregunta, no descarte silencioso |
| 6 | **Question** — qué preguntar después | Determinista | El orden de preguntas es un dato configurable y auditable |
| 7 | **Report** — compone documentos | Determinista (ficha/reporte) + modelo (resumen) | Un documento de búsqueda nunca debe inventar |
| 8 | **Ethical Filter** — qué no publicar | Determinista | Las exclusiones de una ficha pública se explican, no se infieren |

Módulos de percepción (también en el dispositivo): **OCR** con Vision (`VisionOCRService`) y **voz** con Speech (`SpeechFileTranscriptionService`).

### La invariante de seguridad (no negociable)

```swift
validationState = .pending
classificationSuggestedByAI = true
```

Todo lo que produce cualquier módulo de IA entra así. Nada se trata como hecho confirmado hasta que una persona lo valida en `ValidationCenterView`. El usuario siempre puede **Confirmar · Marcar aproximado · Editar · Descartar**.

---

## Privacidad por arquitectura

- **100 % en el dispositivo.** Foundation Models, Vision y Speech corren localmente. No hay servidores de FARO, ni cuentas, ni nube obligatoria.
- **Local-first**: todo el expediente vive en SwiftData, en el dispositivo.
- **Sin red para funcionar**: los motores deterministas garantizan que la app esté completa aunque no haya Apple Intelligence ni conexión.
- **Datos sensibles separados**: el filtro ético determinista excluye información médica, de testigos y conversaciones de toda ficha pública, con la razón visible para la familia.

---

## Frameworks de Apple

| Framework | Uso |
|---|---|
| **SwiftUI** | Toda la interfaz, adaptativa iPhone/iPad (`NavigationStack` / `NavigationSplitView`) |
| **SwiftData** | Base de datos local del expediente, sin backend |
| **Foundation Models** | Resúmenes, clasificación y redacción asistida en el dispositivo, con verificación de disponibilidad |
| **Vision** | OCR de capturas con `VNRecognizeTextRequest`, detección de horas con regex |
| **Speech** | Transcripción de notas de voz (`SFSpeechURLRecognitionRequest`), integrada vía protocolo |
| **MapKit** | Mapa privado del expediente con marcadores por tipo y validación |
| **AVFoundation** | Captura de cámara para importar carteles de búsqueda |
| **PhotosUI** | Selección de fotos y capturas desde galería |
| **CoreGraphics / ImageRenderer** | Exportación de ficha y reporte a PDF e imagen |
| **ShareLink** | Compartir ficha, texto de difusión y PDF |
| **CryptoKit** | Preparado para cifrado de campos sensibles (arquitectura lista, no activo en MVP) |

**Honestidad técnica:** si Foundation Models no está disponible (simulador sin Apple Intelligence, dispositivo no compatible), la app usa automáticamente `MockAIService` y `MockChatAIService` — motores deterministas que mantienen toda la funcionalidad. La UI siempre indica qué motor está activo (`engineName`).

---

## Modelo de datos SwiftData

`CaseFile` es la única entidad raíz insertada en el contexto. Todo cuelga de ella con **borrado en cascada**:

```
CaseFile
 ├─ MissingPerson           (1:1 — datos de la persona, foto local @externalStorage)
 ├─ EvidenceItem[]          (tipo, sensibilidad, validación, texto OCR, archivo local)
 ├─ TimelineEvent[]         (fecha, fuente, confianza, validación, evidencia relacionada)
 ├─ TrustedContact[]        (rol y permisos en la red de confianza)
 ├─ CaseTask[]              (acciones pendientes con prioridad)
 ├─ CaseQuestion[]          (preguntas críticas con estado)
 ├─ LocationRecord[]        (mapa privado: precisión exacta vs. zona general compartible)
 ├─ GeneratedReport[]       (reportes versionados y editables)
 ├─ PublicPoster[]          (ficha pública: campos incluidos/excluidos con razones)
 ├─ IntakeQuestionRecord[]  (estado persistente de cada pregunta del banco de intake)
 ├─ CaseFicha[]             (fichas técnicas versionadas; nunca se borran automáticamente)
 └─ ChatSession[]
      └─ ChatMessage[]      (mensajes del chatbot con rol, tipo y campos pendientes)
```

`CaseFile.touch()` incrementa `dataRevision` y marca fichas generadas como desactualizadas. `CaseFile.touchDocumentsOnly()` actualiza solo la marca temporal sin invalidar fichas.

---

## Arquitectura de la app

**MVVM ligero con servicios detrás de protocolos.** Sin coordinadores ni contenedores de inyección de dependencias.

### Navegación

`RootView` → `@State var router = AppRouter()` inyectado como `@Environment`.

- `router.activeCase == nil` → `HomeView`
- `router.activeCase != nil` → `CaseContainerView`
- `router.showingCrisisFlow` → `fullScreenCover` con `ChatIntakeView` (`.conversational`), `CrisisModeView` (`.guided`), o `PosterImportView` (`.posterImport`) como overlay sobre la pantalla actual

`CaseContainerView` ramifica según `horizontalSizeClass`:
- **iPad (regular):** `NavigationSplitView` con sidebar de 4 secciones agrupadas
- **iPhone (compact):** `NavigationStack` con `CaseDashboardView` y `navigationDestination(for: CaseSection.self)`

### Servicios

`AppServices.shared` (singleton `@MainActor`) instancia todos los servicios al arranque. Nunca se instancian tipos concretos directamente en las vistas.

| Protocolo | Implementación real | Mock |
|---|---|---|
| `AIProcessingServiceProtocol` | `FoundationModelsAIService` | `MockAIService` |
| `CaseAIServiceProtocol` | `FoundationModelsChatAIService` | `MockChatAIService` |
| `OCRServiceProtocol` | `VisionOCRService` | `MockOCRService` |
| `SpeechTranscriptionServiceProtocol` | `SpeechFileTranscriptionService` | `MockSpeechService` |
| `CaseScoringServiceProtocol` | `CaseScoringService` | — |

Servicios sin protocolo (sin mock necesario): `TimelineAnalysisService`, `PosterBuilderService`, `ReportBuilderService`, `PDFExportService`, `FichaComposerService`.

### Motor de lenguaje: `SpanishIntakeEngine`

Núcleo determinista del chatbot, en español coloquial mexicano. Funciones principales:

- `classify(_ text:)` → `UserReplyClassification` (informativo / no sé / estrés / saltar / smalltalk)
- `extractFields(from:activeQuestion:)` → `[DetectedField]` con nombre, edad, hora, lugar, ropa, físico, teléfono
- `assessConfidence(of:)` → `(ConfidenceLevel, ValidationState)` basado en marcadores ("creo", "dicen que", "yo la vi")
- `formalize(fieldKey:rawText:sourceText:)` → redacción formal para ficha ("hoodie gris" → "Sudadera gris con capucha")
- `formalizeTime(from:)` → formato HH:mm con heurística de AM/PM
- `detectNavigationRequest(_:)` → detecta "volver a X" para saltar directamente a un campo

### Flujo de intake conversacional

`ChatIntakeView` → `ChatIntakeViewModel` → `CaseAIServiceProtocol`

El view model gestiona:
- **Autosave** en cada paso: `persist()` con `saveStatus` visible en la UI
- **Memoria persistente**: retoma exactamente donde se quedó entre sesiones
- **Detección de conflictos**: si un dato nuevo contradice uno ya registrado, genera pregunta pendiente y no descarta silenciosamente
- **Repreguntas inteligentes**: cada 3 respuestas, ofrece revisar un dato pendiente con `status == .dontKnow || .skipped`
- **Ficha incremental**: `refreshDraftFicha()` mantiene un borrador `CaseFicha` actualizado en SwiftData en todo momento
- **Navegación por voz**: "volver a ropa" → `detectNavigationRequest` → `reask(question)`

### Importación de carteles: `PosterImportView`

Flujo de cámara con animación de apertura desde el Dynamic Island (pill → rectángulo con aurora → pantalla completa). `PosterFieldExtractor.extract(from:)` extrae nombre, edad, lugar, vestimenta y teléfono de contacto mediante regex deterministas. Todo lo detectado entra como `validationState = .pending`.

### Sistema de diseño: `FaroTheme`

Paleta sobria: **azul noche** (identidad), **blanco cálido** (fondo claro), **gris suave** (texto secundario), **ámbar** (atención/pendientes), **verde confirmado** (datos validados), **rojo** (solo acciones destructivas). Tokens en `FaroTheme` — nunca valores hexadecimales hardcodeados en vistas.

Animaciones: `springSnappy` (botones), `springSmooth` (modales), `springEntrance` (entradas). Modifier `faroEntrance(visible:delay:)` respeta `accessibilityReduceMotion`.

---

## Estructura de archivos

```
Faro/
 ├─ AI/
 │   ├─ AIService.swift              Protocolo + FoundationModelsAIService + MockAIService
 │   └─ ChatCaseIntakeService.swift  SpanishIntakeEngine + FoundationModelsChatAIService + MockChatAIService
 ├─ Models/
 │   ├─ CaseFile.swift               Entidad raíz SwiftData
 │   ├─ MissingPerson.swift
 │   ├─ EvidenceItem.swift
 │   ├─ TimelineEvent.swift
 │   ├─ TrustedContact.swift
 │   ├─ CaseTask.swift
 │   ├─ CaseQuestion.swift
 │   ├─ LocationRecord.swift
 │   ├─ GeneratedReport.swift
 │   ├─ PublicPoster.swift
 │   ├─ CaseFicha.swift
 │   ├─ ChatModels.swift             ChatSession / ChatMessage / IntakeQuestionRecord / DetectedField
 │   └─ SupportTypes.swift           Todos los enums compartidos
 ├─ Views/
 │   ├─ RootView.swift               AppRouter + raíz de navegación
 │   ├─ Home/                        HomeView + EthicsNoticeView + CasesListView
 │   ├─ Case/                        CaseContainerView + CaseDashboardView
 │   ├─ Chat/                        ChatIntakeView + ChatComponents + PendingIntakePanel
 │   ├─ Crisis/                      CrisisModeView (modo paso a paso)
 │   ├─ Import/                      PosterImportView (cámara + extracción de carteles)
 │   ├─ Timeline/                    TimelineView + editores
 │   ├─ Evidence/                    EvidenceVaultView + AddEvidenceView
 │   ├─ Validation/                  ValidationCenterView + ValidationReviewView
 │   ├─ Ficha/                       DraftFichaView + ReviewBeforeGenerateView
 │   ├─ Documents/                   DocumentsView + GeneratedFichaDetailView
 │   ├─ Poster/                      PublicPosterView + PublicPosterPreview
 │   ├─ Report/                      AuthorityReportView + AuthorityReportPreview
 │   ├─ Questions/                   QuestionsView + AnswerQuestionView
 │   ├─ Trust/                       TrustNetworkView + AddContactView
 │   ├─ Map/                         CaseMapView + LocationDetailView
 │   ├─ Privacy/                     PrivacyEthicsView + AIArchitectureView
 │   └─ Settings/                    CaseSettingsView + PersonDetailView
 ├─ ViewModels/
 │   ├─ ChatIntakeViewModel.swift    Estado del chatbot de intake (autosave, conflictos, repreguntas)
 │   └─ CrisisFlowViewModel.swift   Estado del modo paso a paso
 ├─ Services/
 │   ├─ ServiceProtocols.swift       OCRResult / TranscriptionResult / EvidenceClassificationSuggestion / CompletenessRule
 │   ├─ AppServices.swift            Singleton MainActor de todos los servicios
 │   ├─ IntakeQuestionBank.swift     Banco de preguntas configurable (IntakeQuestion / IntakeCategory)
 │   ├─ FichaComposerService.swift   Composición determinista de la ficha técnica
 │   ├─ PosterBuilderService.swift   Filtro ético determinista para la ficha pública
 │   ├─ ReportBuilderService.swift   Reporte formal por tipo (autoridad / colectivo)
 │   ├─ CaseScoringService.swift     Completitud orientativa (11 reglas)
 │   ├─ TimelineAnalysisService.swift Huecos y contradicciones deterministas
 │   └─ TrainingPreparationService.swift AnonymizedCaseSchema (deshabilitado por diseño)
 ├─ OCR/
 │   └─ OCRService.swift             VisionOCRService + MockOCRService + TimeTextDetector
 ├─ Speech/
 │   └─ SpeechService.swift          SpeechFileTranscriptionService + MockSpeechService
 ├─ Export/
 │   └─ PDFExportService.swift       ImageRenderer → PDF / UIImage
 ├─ SampleData/
 │   └─ DemoCaseFactory.swift        Caso demo Mariana López (fechas relativas a "ayer")
 ├─ Theme/
 │   └─ FaroTheme.swift              Sistema de diseño completo + estilos de botón + FaroSectionHeader
 └─ Components/
     ├─ Badges.swift                 SensitivityBadge / ValidationBadge / AISuggestionBadge / ConfidenceBadge
     ├─ CaseDashboardCard.swift
     ├─ CrisisQuestionView.swift
     ├─ EmptyStateView.swift
     ├─ EvidenceCard.swift
     ├─ PendingQuestionCard.swift
     ├─ TimelineEventCard.swift
     └─ TrustContactCard.swift
```

---

## Módulos de la app

1. **Inicio** — Crear caso, abrir caso demo, continuar el más reciente. Advertencia ética antes de crear (`EthicsNoticeView`). Elección de modo: conversacional, paso a paso o importar cartel.
2. **Chatbot de intake** — Extrae múltiples datos de una sola frase, maneja "no sé" y estrés sin bloquear, detecta contradicciones, genera ficha incremental en tiempo real. iPad: chat + ficha en construcción en vivo lado a lado.
3. **Modo Crisis** — 12 pasos, una pregunta por pantalla, tipografía grande. "No lo sé todavía" genera pregunta pendiente; "Saltar" avanza sin culpa. Animaciones direccionales con `CrisisStep`.
4. **Importar cartel** — Cámara con apertura desde Dynamic Island. OCR + `PosterFieldExtractor` extrae campos del cartel. Todo entra como pendiente de revisión.
5. **Dashboard del caso** — Estado general, resumen de IA (con skeleton de carga), siguiente paso recomendado, acciones urgentes (difundir / reportar), completitud orientativa, qué falta por reunir.
6. **Timeline inteligente** — Eventos cronológicos, huecos de más de 3 horas señalados, alerta de contradicción cuando hay dos marcadores de "última vez vista" con horarios distintos.
7. **Vault de evidencia** — Capturas (OCR con Vision), notas escritas, audios (transcripción con Speech) y ubicaciones. Cada elemento pasa por `ValidationReviewView`.
8. **Centro de validación** — Cola unificada de todo lo pendiente de revisión humana. Nada sugerido automáticamente queda fuera de esta cola.
9. **Ficha técnica** — `FichaComposerService` genera el documento formal de forma determinista. Versionada: `CaseFicha` nunca se borra automáticamente. Borrador incremental durante la conversación.
10. **Ficha pública ética** — `PosterBuilderService` aplica filtro determinista. Campos incluidos y excluidos con razón visible. Exporta PDF, imagen y texto para WhatsApp (3 tonos: formal, comunitario, urgente). Requiere aprobación explícita de la familia.
11. **Reporte formal** — Documento estructurado para autoridad o colectivo: hechos confirmados vs. pendientes, evidencia, ubicaciones, preguntas urgentes. Editable y exportable a PDF.
12. **Preguntas pendientes** — Generadas según reglas de completitud. La familia puede añadir las suyas y marcarlas como resueltas o no aplica.
13. **Red de confianza** — Contactos con roles diferenciados (administra / documenta / difunde / legal / emocional / observador). Local-first; sincronización con CloudKit como evolución futura.
14. **Mapa privado** — MapKit con marcadores por tipo (última ubicación, frecuente, mencionado, descartado). Zona general pública vs. ubicación precisa privada.
15. **Privacidad y ética** — Compromisos en lenguaje claro y enlace a `AIArchitectureView` con detalle técnico del sistema de IA.

---

## Cómo correr el proyecto

**Requisitos:** Xcode 26+, simulador o dispositivo con iOS/iPadOS 26+.

```bash
# Abrir en Xcode (recomendado)
open Faro.xcodeproj

# Build por línea de comandos
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Faro.xcodeproj -scheme Faro -sdk iphonesimulator build
```

No requiere configuración adicional, internet, cuentas ni dependencias externas. No hay Package.swift ni CocoaPods.

**Argumentos de lanzamiento útiles:**
- `-FaroOpenDemo` — abre el caso demo directamente al arrancar (ideal para presentaciones)
- `-FaroIntakeSelfTest` — ejecuta el flujo de intake de forma programática para validar escenarios

---

## Caso demo

En la pantalla de inicio, toca **"Abrir caso demo"**. Se carga el caso ficticio de **Mariana López, 22 años** (zona universitaria ficticia, datos 100 % inventados) con:

- Último mensaje de WhatsApp con OCR simulado (hora 21:47)
- Nota de voz transcrita
- Ubicación compartida que se interrumpe a las 21:52
- Un rumor sin confirmar (excluido de la ficha pública)
- Timeline con **contradicción detectada** entre dos horarios distintos (21:30 vs. 22:05)
- Preguntas críticas pendientes
- Red de confianza con 4 contactos y roles
- Ficha pública con campos excluidos y sus razones
- Reporte formal para autoridad

Las fechas se calculan como "ayer" para que la demo siempre se vea reciente. Se puede reiniciar desde **Ajustes del caso → Reiniciar caso demo**.

---

## Flujo de presentación sugerido (4–5 minutos)

1. Abrir FARO → **"Abrir caso demo"** (Mariana López)
2. **Evidencia → Agregar → Captura de pantalla** → usar captura simulada (demo) → OCR detecta texto y la hora 21:47 → ver clasificación sugerida por IA
3. **Centro de validación** → revisar el dato → agregar el evento sugerido al timeline → confirmar
4. **Línea de tiempo** → ver el nuevo evento integrado, el hueco nocturno marcado y la alerta de dos horarios distintos
5. **Ficha pública** → mostrar campos incluidos/excluidos con razones → aprobar → exportar PDF
6. **Reporte formal** → hechos confirmados vs. pendientes → exportar
7. **Privacidad y ética → Arquitectura de IA** → mostrar qué decide un modelo y qué deciden reglas
8. Cierre: *"FARO no promete encontrar a una persona. Promete que una familia no pierda las primeras horas tratando de entender qué hacer."*

---

## `TrainingPreparationService`: arquitectura preparada para aprender

`AnonymizedCaseSchema` define la **forma** de un dataset futuro (estructura, nunca contenido personal). Hoy está **deshabilitado por diseño**: `exportConsentGranted = false`, sin UI para activarlo. Una versión futura solo podría usarlo bajo consentimiento informado, anonimización verificada, autorización institucional y revisión ética independiente.

El `IntakeQuestionBank` es la otra mitad de esta arquitectura: como las preguntas son datos y no código, un análisis futuro de reportes anonimizados podría reordenar prioridades y ajustar redacciones sin tocar la interfaz.

---

## Limitaciones éticas (por diseño)

- No encuentra personas, no predice ubicaciones, no identifica responsables, no valida pruebas legalmente.
- No publica rumores ni datos sin confirmar; los excluye explícitamente de la difusión con razón visible.
- Nada generado por IA se trata como hecho sin validación humana.
- No reemplaza denuncias, protocolos oficiales ni asesoría profesional, y lo dice en la interfaz y en cada documento exportado.
- Datos sensibles (salud, testigos, conversaciones, rutinas) separados estrictamente de lo público.

---

## Accesibilidad

- **Dynamic Type** en toda la interfaz
- **VoiceOver**: `accessibilityLabel` y `accessibilityHint` descriptivos en cada elemento interactivo
- **Color no es el único canal**: los estados siempre se comunican con texto e ícono además del color
- **Reducir movimiento**: `faroEntrance` y las transiciones de `CrisisModeView` respetan `accessibilityReduceMotion`
- **Objetivos táctiles**: mínimo 44 pt en todos los botones

---

## Modelo de negocio

**B2B2C social.** La app familiar es **gratis, siempre**: crear caso, organizar evidencia, generar ficha y exportar reporte no cuestan.

La monetización viene de **capacidad institucional**: licencias para universidades, colectivos, clínicas legales, ONGs y municipios; capacitación e implementación; white label para colectivos; panel de gestión multi-caso; talleres de documentación digital segura.

> No monetizamos el dolor de la familia; monetizamos la capacidad institucional de acompañar mejor.

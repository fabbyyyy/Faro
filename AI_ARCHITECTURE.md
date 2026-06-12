# Arquitectura de IA de FARO

> **Principio rector:** la IA organiza, sugiere y redacta; **nunca decide los
> hechos de un expediente**. Todo lo que produce entra como *pendiente de
> revisión* y solo una persona lo confirma.

FARO no es "un chatbot con un modelo grande detrás". Es una **arquitectura
modular de IA en el dispositivo**, donde cada módulo usa la herramienta
correcta para su tarea: un modelo generativo cuando aporta lenguaje natural,
y reglas deterministas cuando lo que está en juego es la **exactitud de un
dato** o la **seguridad de una familia**. Esa mezcla es una decisión de
diseño, no una limitación.

---

## 1. Modelo híbrido en dos capas

Toda la IA vive detrás de **protocolos**, con selección de motor en tiempo de
ejecución y respaldo determinista que mantiene la app completa **sin red, sin
cuenta y sin permisos concedidos**.

| Capa | Protocolo | Motor real | Respaldo | Para qué |
|---|---|---|---|---|
| Procesamiento del caso | `AIProcessingServiceProtocol` | `FoundationModelsAIService` | `MockAIService` | Clasificar evidencia, sugerir eventos, resumir, redactar difusión |
| Conversación de intake | `CaseAIServiceProtocol` | `FoundationModelsChatAIService` | `MockChatAIService` | Entender al usuario, extraer campos, sugerir la siguiente pregunta, componer la ficha |

`AIServiceFactory.makeService()` y `ChatAIServiceFactory.makeService()` eligen
**Foundation Models (Apple Intelligence)** cuando el sistema lo ofrece
(`SystemLanguageModel.default.availability == .available`); si no, devuelven el
motor local determinista. La interfaz **siempre indica qué motor está activo**
(`engineName`), por honestidad técnica.

> **Clave de diseño:** incluso cuando Foundation Models está disponible, la
> extracción y formalización de datos siguen siendo deterministas. El modelo
> generativo solo **pule el tono** de la respuesta. Un modelo no debe inventar
> el dato de una familia.

---

## 2. Los módulos de IA

Aunque comparten implementación, conceptualmente FARO opera ocho módulos
especializados. La columna **Motor** es lo importante: marca dónde decide un
modelo y dónde deciden reglas auditables.

| # | Módulo | Implementación | Motor | Por qué ese motor |
|---|---|---|---|---|
| 1 | **Intake** (entiende al usuario) | `SpanishIntakeEngine.classify` + `CaseAIService.processUserMessage` | Determinista (clasifica) + modelo (tono) | Clasificar "no sé / estrés / dato" debe ser predecible; el modelo solo suaviza la redacción |
| 2 | **Formalizer** (informal → técnico) | `SpanishIntakeEngine.formalize`, `FichaComposerService` | Determinista | "traía una hoodie gris" → "Vestimenta referida: sudadera gris (dato pendiente)" debe ser reproducible |
| 3 | **Sensitivity** (detecta lo sensible) | `classifyEvidence` + `validateSensitiveInformation` | Determinista (reglas) + sugerencia de modelo | Lo médico/privado nunca debe filtrarse por una alucinación |
| 4 | **Timeline** (ordena y detecta huecos) | `suggestTimelineEvents`, `TimelineAnalysisService.detectGaps` | Determinista | Las horas se detectan por regex; los huecos por aritmética explicable |
| 5 | **Contradiction** (detecta conflictos) | `TimelineAnalysisService.detectConflicts` + `ChatIntakeViewModel.flagConflictIfNeeded` | Determinista | "sudadera gris" vs "playera roja" → genera una pregunta, no un descarte silencioso |
| 6 | **Question** (qué preguntar después) | `suggestNextQuestion`, `detectMissingFields`, `IntakeQuestionBank` | Determinista (datos, no código) | El orden de preguntas es un dato configurable y auditable |
| 7 | **Report** (compone documentos) | `FichaComposerService`, `ReportBuilderService`, `summarizeCase` | Determinista (ficha/reporte) + modelo (resumen) | Un documento de búsqueda debe ser sobrio y nunca inventar; el resumen de lectura sí puede pulirse |
| 8 | **Ethical Filter** (qué no publicar) | `PosterBuilderService` | Determinista | Qué se excluye de una ficha pública **no puede depender de un modelo**; cada exclusión se explica |

Módulos de percepción que alimentan a los anteriores, también en el dispositivo:

- **OCR:** `VisionOCRService` (Apple Vision) extrae texto de capturas.
- **Voz:** `SpeechFileTranscriptionService` (Apple Speech) transcribe notas de voz.

---

## 3. La invariante de seguridad (no negociable)

Todo lo que produce cualquier módulo de IA entra al expediente así:

```
validationState = .pending
classificationSuggestedByAI = true
```

Nada se trata como hecho confirmado hasta que una persona lo valida en
`ValidationCenterView` / `ValidationReviewView`. El usuario siempre puede
**Confirmar · Marcar aproximado · Editar · Descartar**. Esta regla es el
corazón ético del producto y no se omite al agregar funciones de IA.

Además, cada dato lleva su **confianza por origen**
(`EvidenceKind.sourceConfidence`): una captura original pesa más que un
testimonio de tercero, y un rumor queda como *no confirmado* por definición.

---

## 4. Privacidad por arquitectura

- **100% en el dispositivo.** Foundation Models, Vision y Speech corren
  localmente. No hay servidores de FARO, ni cuentas, ni nube obligatoria.
- **Local-first:** todo el expediente vive en SwiftData, en el dispositivo.
- **Sin red para funcionar:** los motores deterministas garantizan que la app
  esté completa aunque no haya Apple Intelligence ni conexión.
- **Datos sensibles separados, no difundidos:** el filtro ético determinista
  los excluye de toda ficha pública, con la razón visible.

---

## 5. Por qué determinista-por-diseño es una ventaja

En el contexto de una desaparición, tres propiedades importan más que la
"inteligencia" de un modelo:

1. **Reproducibilidad** — la demo y el resultado son los mismos cada vez.
2. **Explicabilidad** — cada clasificación, exclusión y alerta tiene una razón
   que se puede mostrar y auditar.
3. **Seguridad** — un modelo generativo no puede filtrar un dato médico ni
   "inventar" una ubicación, porque esas decisiones son código, no inferencia.

El modelo generativo aporta donde es seguro y valioso: **lenguaje humano y
empático en crisis**. Todo lo demás está bajo control determinista.

---

## 6. Cómo se ve la IA en la app (visible para quien evalúa)

- Etiqueta **"Sugerido por IA · requiere revisión"** (`AISuggestionBadge`).
- Indicador del **motor activo** ("Foundation Models" o "Asistente local").
- **Confianza por origen** en cada evidencia.
- **Conflictos** detectados como preguntas pendientes.
- **Huecos** marcados en la línea de tiempo.
- **Exclusiones** explicadas, una por una, en la ficha pública.
- Texto extraído con **Vision OCR** y voz con **Speech**, siempre pendiente de validar.

---

## 7. Preparada para evolucionar (sin rediseñarse)

`TrainingPreparationService` define `AnonymizedCaseSchema`: la **forma** de un
dataset futuro (estructura, nunca contenido). Hoy está **deshabilitado por
diseño** (`exportConsentGranted = false`, sin UI para activarlo). Una versión
futura solo podría usarlo bajo consentimiento informado, anonimización
verificada, autorización institucional y revisión ética. Demuestra que la
arquitectura puede aprender mañana sin sacrificar la privacidad de hoy.

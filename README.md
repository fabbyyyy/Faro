# FARO

> **FARO no promete encontrar a una persona. Promete que una familia no pierda las primeras horas tratando de entender qué hacer.**

App para iPhone y iPad construida con **Swift, SwiftUI y SwiftData**, con **IA 100 % en el dispositivo**. Desarrollada para el **Swift Challenge Fest 2026** — reto *Human-Centered AI resolviendo un ODS*.

---

## El problema

Cuando una persona desaparece, la familia entra en crisis: miedo, llamadas, capturas de WhatsApp, audios, rumores, recuerdos incompletos, datos médicos. Justo cuando más claridad se necesita, la información **se pierde, se duplica, se comparte mal o se mezcla con datos no confirmados**.

FARO convierte ese caos en un **expediente vivo, privado, validado y accionable** durante las primeras 72 horas: organiza capturas, audios, ubicaciones, testimonios y datos sueltos, separa lo confirmado de lo pendiente, y prepara materiales útiles para búsqueda, acompañamiento o denuncia.

FARO **no sustituye** a autoridades, colectivos, abogados ni protocolos oficiales. Solo estructura información, reduce carga mental, evita difusión irresponsable y protege datos sensibles.

## ODS que aborda

- **ODS 16 — Paz, justicia e instituciones sólidas**: documentación clara y ordenada que facilita la interacción con instituciones y colectivos de búsqueda.
- **ODS 10 — Reducción de desigualdades**: no todas las familias tienen acceso a asesoría legal, acompañamiento institucional o redes organizadas. FARO acerca esa capacidad de documentación a cualquier familia con un iPhone.

## Por qué es Human-Centered AI

La IA está **al servicio de la familia, no al centro del producto**:

- **La IA sugiere, la persona decide.** Todo lo extraído por OCR, transcripción o modelos generativos entra al expediente como *pendiente de revisar*. Nada se vuelve "hecho" sin validación humana.
- **Estados de confianza explícitos**: confirmado, pendiente, aproximado, contradictorio, descartado. La interfaz marca claramente lo "Sugerido por IA · requiere revisión".
- **Crisis-first design**: una pregunta por pantalla, tipografía grande, "No lo sé todavía" y "Saltar por ahora" sin culpa. Una persona en crisis no contesta un censo.
- **Filtro ético determinista**: qué se publica y qué se protege en la ficha pública NO lo decide un modelo; lo decide código transparente que explica cada exclusión.

## Frameworks de Apple

| Framework | Uso |
|---|---|
| **SwiftUI** | Toda la interfaz, adaptativa iPhone/iPad (`NavigationStack` / `NavigationSplitView`) |
| **SwiftData** | Base de datos local del expediente (local-first, sin backend) |
| **Foundation Models** | Resúmenes, clasificación y redacción asistida en el dispositivo (con verificación de disponibilidad) |
| **Vision** | OCR de capturas de pantalla con detección de horas |
| **Speech** | Transcripción de notas de voz en el dispositivo (integrada vía protocolo) |
| **MapKit** | Mapa privado del expediente |
| **PhotosUI** | Selección de fotos y capturas |
| **CoreGraphics / ImageRenderer** | Exportación de ficha y reporte a PDF e imagen |
| **ShareLink** | Compartir ficha, texto y PDF |

**Honestidad técnica:** si Foundation Models no está disponible en el entorno (simulador sin Apple Intelligence, dispositivo no compatible), `AIServiceFactory` cae automáticamente a un **asistente local determinista** (`MockAIService`). La UI siempre muestra qué motor está activo. Lo mismo aplica a Speech: el flujo de demo usa transcripción simulada claramente etiquetada.

## Cómo funciona SwiftData

`CaseFile` es la entidad raíz; todo cuelga de ella con **borrado en cascada**:

```
CaseFile
 ├─ MissingPerson      (datos de la persona, foto local opcional)
 ├─ EvidenceItem[]     (tipo, sensibilidad, validación, texto extraído, archivo local)
 ├─ TimelineEvent[]    (fecha, fuente, confianza, validación, evidencia relacionada)
 ├─ TrustedContact[]   (rol y permisos en la red de confianza)
 ├─ CaseTask[]         (acciones pendientes con prioridad)
 ├─ CaseQuestion[]     (preguntas críticas)
 ├─ LocationRecord[]   (mapa privado: precisión, zona general compartible)
 ├─ GeneratedReport[]  (reportes versionados y editables)
 └─ PublicPoster[]     (ficha pública: campos incluidos/excluidos con razones)
```

Todo se guarda **solo en el dispositivo**. No hay cuentas, servidores ni nube obligatoria. La app funciona completamente offline.

## Módulos

1. **Inicio** — Crear caso, abrir caso demo, continuar caso. Advertencia ética antes de crear.
2. **Modo Crisis** — Registro guiado: una pregunta por pantalla, todo se puede saltar.
3. **Dashboard del Caso** — Estado general, completitud orientativa, qué falta por reunir.
4. **Timeline Inteligente** — Eventos cronológicos con detección de huecos y contradicciones ("Hay dos horarios distintos. Revisa cuál está confirmado").
5. **Vault de Evidencia** — Capturas (OCR), notas, audios (transcripción) y ubicaciones, clasificados por tipo y sensibilidad.
6. **Validación Humana** — Cola de revisión obligatoria para todo lo sugerido automáticamente.
7. **Ficha Pública Ética** — Genera ficha segura, explica qué excluye y por qué, exporta PDF/imagen y texto sobrio para WhatsApp con tres tonos.
8. **Reporte Formal** — Documento estructurado para autoridad o colectivo, editable y exportable a PDF, con nota de alcance.
9. **Preguntas Pendientes** — Preguntas críticas generadas según lo que falta.
10. **Red de Confianza** — Contactos con roles y permisos diferenciados (local-first).
11. **Mapa Privado** — MapKit con última ubicación, lugares frecuentes, puntos mencionados y descartados.
12. **Privacidad y Ética** — Compromisos y límites de la app en lenguaje claro.

## Cómo correr el proyecto

1. Requisitos: **Xcode 26+**, simulador o dispositivo con iOS/iPadOS 26+.
2. Abrir `Faro.xcodeproj`.
3. Seleccionar el esquema **Faro** y un simulador (iPhone 16 Pro o iPad Pro 11").
4. `⌘R`. No requiere configuración adicional, internet ni cuentas.

## Caso demo

En la pantalla de inicio, toca **"Abrir caso demo"**. Se carga el caso ficticio de **Mariana López, 22 años** (zona universitaria ficticia) con: último mensaje, nota de voz transcrita, ubicación compartida, un rumor sin confirmar, timeline con contradicción de horarios, preguntas pendientes, red de confianza, ficha pública y reporte formal. Se puede reiniciar desde **Ajustes del caso → Reiniciar caso demo**.

## Flujo de presentación (4 minutos)

1. Abrir FARO → **Abrir caso demo**.
2. **Evidencia → Agregar → Captura** → usar captura simulada → OCR detecta texto y la hora 21:47.
3. **Validación humana**: revisar el dato, ver la clasificación sugerida por IA, agregar el evento sugerido al timeline, confirmar.
4. **Timeline**: ver el evento integrado, el hueco nocturno detectado y la alerta de dos horarios distintos.
5. **Ficha pública**: generar/revisar, mostrar **qué se excluyó y por qué** (dirección exacta, testigos, datos médicos, conversaciones, rumores), aprobar y exportar.
6. **Reporte formal**: hechos confirmados vs. pendientes, exportar PDF.
7. Cierre: *"FARO no promete encontrar a una persona. Promete que una familia no pierda las primeras horas tratando de entender qué hacer."*

## Limitaciones éticas (por diseño)

- No encuentra personas, no predice ubicaciones, no identifica responsables, no valida pruebas legalmente.
- No publica rumores ni datos sin confirmar; los excluye explícitamente de la difusión.
- Nada generado por IA se trata como hecho sin validación humana.
- No reemplaza denuncias, protocolos oficiales ni asesoría profesional, y lo dice en la propia interfaz y en cada documento exportado.
- Datos sensibles (salud, testigos, conversaciones) separados estrictamente de lo público; arquitectura preparada para cifrado de campos con CryptoKit.

## Modelo de negocio

**B2B2C social.** La app familiar es **gratis, siempre**: crear caso, organizar evidencia, generar ficha y exportar reporte básico no cuestan.

La monetización viene de **capacidad institucional**: licencias para universidades, colectivos, clínicas legales, ONGs, municipios y programas de responsabilidad social; capacitación e implementación; white label para colectivos; panel de gestión multi-caso; talleres de documentación digital segura.

> No monetizamos el dolor de la familia; monetizamos la capacidad institucional de acompañar mejor.

## Arquitectura

MVVM ligera con servicios detrás de protocolos:

```
Faro/
 ├─ Models/        Entidades SwiftData + enums de estado
 ├─ Views/         Pantallas por módulo (Home, Crisis, Case, Timeline, …)
 ├─ ViewModels/    CrisisFlowViewModel
 ├─ Services/      Protocolos + scoring, análisis, ficha, reporte
 ├─ AI/            Foundation Models + asistente local de demo
 ├─ OCR/           Vision OCR + mock
 ├─ Speech/        Speech + mock
 ├─ Export/        PDF/imagen con ImageRenderer
 ├─ SampleData/    Caso demo Mariana López
 ├─ Theme/         Sistema de diseño (azul noche, blanco cálido, ámbar)
 └─ Components/    Cards, badges y vistas reutilizables
```

Accesibilidad: Dynamic Type, VoiceOver con labels y hints descriptivos, estados comunicados con texto e ícono (nunca solo color), botones grandes, "Información sensible" dicha explícitamente.

# CLAUDE.md — Instrucciones persistentes de LOOKSY

Lee este archivo completo antes de trabajar. Luego revisa `docs/PROGRESS.md` (estado real y pendientes).
Cuando el usuario diga **"Continúa LOOKSY"**: inspecciona el repositorio, verifica el último estado de
GitHub Actions y retoma desde el último avance **verificado**. No repitas trabajo hecho ni reemplaces
una versión funcional por un prototipo.

## 1. Objetivo

LOOKSY es un armario digital y estilista personal **100 % nativo para iPhone** (Swift + SwiftUI), en español:

- Fotografiar/importar prendas reales y organizarlas.
- Pedir outfits en lenguaje natural ("algo casual con mis jeans negros para un café").
- Generar combinaciones coherentes **solo con prendas existentes** y convertirlas en collages flat-lay editables.
- Abrir búsquedas **auténticas** de Pinterest (enlaces públicos de búsqueda) y guardar referencias.
- "Recrea este look" y comparación Inspiración vs. Mi look con criterios explicables.
- Looks guardados, colecciones, calendario semanal local, preferencias y respaldos locales.

## 2. Restricciones (no negociables)

- **Costo cero**: sin APIs de IA comerciales, sin Firebase, sin backend, sin hosting, sin Apple Developer Program.
- **Sin Mac**: el usuario trabaja en Windows. Se compila en **GitHub Actions** (runner macOS gratuito; el repo es público).
- Instalación con **AltStore Classic + AltServer (Windows)** usando Apple ID gratuito → ver `docs/INSTALL_WINDOWS.md`.
- Sin scraping ni endpoints privados de Pinterest. **Nunca** inventar pines, resultados, análisis ni porcentajes.
- Si solo hay una URL, no afirmar que se analizó la imagen.
- Funciona offline salvo abrir Pinterest/enlaces.
- Nunca guardar certificados, perfiles, Apple ID ni contraseñas en el repo o en Actions.
- Ninguna foto personal ni respaldo debe subirse al repo (ver `.gitignore`). No registrar datos personales en logs.

## 3. Stack y arquitectura

- iOS 17+, SwiftUI, SwiftData, Observation (`@Observable`), PhotosUI, Vision (`VNGenerateForegroundInstanceMaskRequest`),
  Core Image, ImageRenderer, Photos (solo agregar), CryptoKit, UniformTypeIdentifiers. Sin dependencias externas.
- Swift 5 language mode con concurrencia mínima (`SWIFT_VERSION 5.0`, `SWIFT_STRICT_CONCURRENCY minimal`).
  Migrar a Swift 6 es un pendiente: hacerlo solo cuando CI esté verde y con cambios pequeños.
- **XcodeGen**: `project.yml` es la fuente de verdad. El `.xcodeproj` y `LOOKSY/Resources/Info.plist` se generan (no se versionan).
- MVVM: Vistas en `Views/`, estado en `ViewModels/`, lógica pura en `Services/` (testeable, sin UI).

```
LOOKSY/
  App/          LOOKSYApp (ModelContainer), RootTabView (5 pestañas), AppRouter
  Models/       Garment, Look, LookCollection, PlannedOutfit, InspirationReference (SwiftData)
                GarmentCategory/OutfitSlot, FashionAttributes, FashionColor, CollageComposition,
                UserPreferences, GarmentSnapshot (valor inmutable para el motor)
  Services/     ImageStorageService, ImageProcessingService, WardrobeService, PreferencesService,
                CollageLayoutEngine, CollageService, LookService, PinterestSearchService,
                RecreationService, BackupService
  Services/Stylist/  FashionLexicon, OutfitRequest, OutfitRequestParser, ColorHarmony,
                     OutfitRecommendationService (+ ScoringContext)
  ViewModels/   WardrobeViewModel, GarmentEditorViewModel, StylistViewModel, CollageEditorViewModel
  Views/        Home, Wardrobe, Stylist, Collage, Inspiration, Looks, Settings
  Components/   tarjetas, chips, FlowLayout, selector de colores, cámara, imágenes asíncronas
  Utilities/    Theme, RGBColor, SpanishGrammar, AppLogger
  Extensions/   Color+Hex, UIImage+Processing, String+Normalize
LOOKSYTests/    XCTest (modelos, persistencia, parser, motor, Pinterest, collage, respaldos, recreación)
scripts/ci/     scripts usados por el workflow
.github/workflows/build-ios.yml
docs/           PROGRESS.md, INSTALL_WINDOWS.md
```

### Decisiones clave
- Las fotos viven en `Application Support/LOOKSY/Images` (JPEG ≤1800 px + miniatura 420 px; recortes PNG con alfa).
  Los modelos guardan **solo nombres de archivo**.
- Enums se guardan como `String` crudo en SwiftData (`categoryRaw`, etc.) con accesores tipados → migraciones seguras.
- Las relaciones entre modelos son **por UUID** (no `@Relationship`): si se borra una prenda, los looks conservan el ID
  y la UI muestra "prenda eliminada".
- El motor de outfits trabaja con `GarmentSnapshot` (structs) → puro, determinista, se ejecuta fuera del hilo principal.
- Preferencias: JSON en `Application Support/LOOKSY/preferences.json`.
- Respaldo: un `.json` con registros + fotos en base64 y SHA-256 por archivo (`BackupArchive`, formato v1).
- Bundle ID **estable**: `com.angiemarz.looksy` (no cambiarlo: AltStore lo usa para actualizar sin perder datos).

## 4. Compilación (sin Mac)

Workflow `.github/workflows/build-ios.yml` (push a `main` y `claude/**`, PR a `main`, manual):
1. `test`: XcodeGen → `xcodebuild test` en un simulador iPhone disponible.
2. `build`: `xcodebuild build -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO`,
   valida plataforma (Mach-O platform 2, arm64, `CFBundleSupportedPlatforms=iPhoneOS`), crea
   `LOOKSY-unsigned.ipa` y `LOOKSY-adhoc.ipa` (firma ad-hoc `codesign -s -`, sin certificados) y los sube como artefacto `LOOKSY-ipa`.
- XcodeGen fijado en `XCODEGEN_VERSION` (descarga del release oficial; Homebrew como respaldo).
- No hay Swift en el contenedor Linux de Claude Code: **la única verificación de compilación es CI**. No declarar
  "compila" sin evidencia del workflow. Limitar reintentos a fallos concretos.

## 5. Convenciones de código

- Interfaz 100 % en español; código, nombres y comentarios técnicos en inglés.
- Colores y espaciados desde `Theme` (rosa `#D8A7B1`, beige `#E8DDD0`, crema `#F5EFE8`, blanco cálido `#FAF8F5`,
  texto `#292522`; acento accesible `#A35E6E`). Soporta modo oscuro.
- Toda acción visible debe funcionar o indicar claramente que está pendiente. Confirmar antes de borrar.
- Etiquetas de accesibilidad en controles con solo íconos; respetar Dynamic Type (usar estilos de texto).
- Trabajo pesado (imágenes, motor) fuera del hilo principal (`Task.detached`). SwiftData y UI en `@MainActor`.
- Nada de `print` con datos del usuario; usar `AppLogger` solo con eventos técnicos/cuentas.
- Añadir tests a `LOOKSYTests` para toda lógica nueva en `Services/`.

## 6. Git, commits y PRs

- Rama de trabajo actual: `claude/dreamy-hypatia-v3l33w`. Nunca `push --force`, nunca reescribir historia,
  nunca merge a `main` sin aprobación del usuario.
- Conventional Commits (`feat:`, `fix:`, `ci:`, `test:`, `docs:`, `chore:`).
- Flujo: revisar diff → validaciones disponibles → commit → push → revisar CI → corregir errores concretos.
- PR hacia `main` con: funcionalidades, archivos, pruebas, pendientes, estado de compilación y cómo verificar.

## 7. Privacidad

Datos solo en el iPhone. Sin cuentas ni servidores. Pinterest solo se abre a petición. El respaldo lo exporta el usuario.

## 8. Estado y continuidad

El estado detallado (implementado / probado en CI / compilado / instalado en iPhone) está en `docs/PROGRESS.md`.
Al terminar cada sesión: actualizar `docs/PROGRESS.md` y este archivo si cambió la arquitectura, hacer commit y push,
reportar hashes, estado de CI y el siguiente paso concreto.

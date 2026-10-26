# LOOKSY

Armario digital y estilista personal para iPhone: 100 % nativo (Swift + SwiftUI), en español, privado y sin costo.

- 📸 **Mi armario**: fotografía o importa tus prendas, detecta el color en el dispositivo, quita el fondo con Vision,
  recorta, gira, filtra, busca, marca favoritas y disponibilidad.
- ✨ **Crear outfit**: escribe lo que necesitas ("algo casual con mis jeans negros para un café") y LOOKSY combina
  prendas **reales** de tu armario con reglas explicables (estilo, ocasión, formalidad, clima, armonía de color,
  tus preferencias). Sustituye prendas, genera alternativas y guarda looks.
- 🧩 **Collages flat lay** automáticos con tus fotos; edítalos con gestos (mover, pellizcar, rotar, capas, fondo,
  formatos 1:1, 4:5, 9:16) y expórtalos en PNG a Fotos o con el menú Compartir.
- 📌 **Inspiración**: búsquedas auténticas de Pinterest en español e inglés, referencias guardadas (enlaces o capturas),
  **Recrea este look** y comparación **Inspiración vs. mi look** con criterios explicables.
- 🗓 **Mis looks**: favoritos, colecciones y calendario semanal local.
- 🔒 **Privacidad**: todo se guarda solo en tu iPhone. Respaldo y restauración en un archivo local.

## Compilar sin Mac

El proyecto se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) y se compila en
GitHub Actions (`.github/workflows/build-ios.yml`) con un runner macOS gratuito. Cada ejecución publica el artefacto
**LOOKSY-ipa** con `LOOKSY-adhoc.ipa` y `LOOKSY-unsigned.ipa`.

Para instalarlo en tu iPhone desde Windows con AltStore Classic, sigue [`docs/INSTALL_WINDOWS.md`](docs/INSTALL_WINDOWS.md).

## Estructura

Consulta [`CLAUDE.md`](CLAUDE.md) (arquitectura y reglas) y [`docs/PROGRESS.md`](docs/PROGRESS.md) (estado).

## Requisitos

- iPhone con iOS 17 o posterior.
- Para compilar localmente (opcional, requiere Mac): Xcode 15+ y `brew install xcodegen && xcodegen generate`.

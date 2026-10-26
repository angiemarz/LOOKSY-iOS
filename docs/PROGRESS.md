# LOOKSY — Progreso

Leyenda: **Implementado** (código en el repo) · **Probado (CI)** (XCTest en simulador vía GitHub Actions) ·
**Compilado** (build `iphoneos` en Actions) · **En iPhone** (probado por la usuaria en un dispositivo físico).

_Última actualización: 2026-10-26 — sesión 1._

## Estado de verificación

| Elemento | Estado |
|---|---|
| Compilación en GitHub Actions | ⏳ Pendiente del primer run de CI. |
| Tests XCTest | Escritos; **no ejecutados** (requieren CI). |
| IPA | Script de empaquetado/validación listo; **no generada** todavía. |
| Instalación en iPhone | No probada. |

> En el contenedor de Claude Code no hay compilador Swift (Linux sin toolchain), así que la única verificación posible
> es GitHub Actions. Hasta ver un run verde, considera el código **implementado pero no compilado**.

## Fases

### Fase 1 — Base nativa y compilación — Implementado
- XcodeGen (`project.yml`), Info.plist generado (permisos de cámara/Fotos, Bundle ID estable `com.angiemarz.looksy`).
- Workflow `build-ios.yml`: tests en simulador + build `iphoneos` sin firma + validación Mach-O + IPA unsigned/ad-hoc.
- App SwiftUI con 5 pestañas (Ajustes desde el engrane de Inicio), tema rosa/beige con modo oscuro, ícono.
- SwiftData: `Garment`, `Look`, `LookCollection`, `PlannedOutfit`, `InspirationReference`.
- Armario: importar varias fotos, cámara, crear/editar/duplicar/eliminar (con confirmación y aviso si está en looks),
  filtros (categoría, color, estilo, temporada, etiqueta, favoritas, disponibles), búsqueda, orden, favoritas, disponibilidad.
- Fotos: almacenamiento en disco con miniaturas, detección local de colores (Lab, ignora fondo/transparencia),
  quitar fondo con Vision (con mensajes si falla), auto-encuadre, recorte manual con esquinas, giro 90°.

### Fase 2 — Generador de outfits — Implementado
- Parser local en español/inglés (prendas+colores, ocasiones, estilos, clima, comodidad, "sin tacones", exclusiones,
  prendas por nombre). Muestra "Entendí: …".
- Motor de reglas explicables: filtros, bloqueo de prendas pedidas, puntuación (estilo, ocasión, formalidad, temporada,
  clima, armonía de color, estampados, preferencias), capas/bolso/accesorios, selección variada (3–6), sin duplicados,
  explicación y avisos. Explica lo que falta si el armario no alcanza.
- Tarjeta de resultado: collage automático, prendas, explicación, Guardar, Editar, Cambiar/Añadir prenda,
  Alternativa, Pinterest; botón global "Generar alternativas".

### Fase 3 — Collages — Implementado
- Layout flat lay automático (superior, inferior, calzado, bolso al costado, accesorios alrededor; 1:1, 4:5, 9:16).
- Editor: arrastrar, pellizcar, rotar (gestos + sliders accesibles), capas, quitar, añadir, restablecer, fondo
  (presets + selector), tarjetas limpias para fotos con fondo, guardar composición (JSON en el look).
- Exportación PNG 1080 px: guardar en Fotos (permiso solo-agregar) y compartir.

### Fase 4 — Pinterest y recreación — Implementado
- Generador de búsquedas ES/EN (desde texto, prendas, outfit, paleta, estilo) → URL pública de búsqueda de Pinterest.
- Guardar búsquedas/enlaces/capturas como referencias, favoritas, notas, vínculos con looks y prendas, compartir.
- "Recrea este look": editor manual de prendas de la referencia (paleta detectada si hay imagen; aviso honesto si solo
  hay URL) → 3 versiones: más parecida (indica faltantes), solo con mi armario (sustitutos), creativa.
- Comparación Inspiración vs. Mi look (vistas A/B/lado a lado) con criterios explicables, sin porcentajes ficticios.

### Fase 5 — Organización — Implementado
- Preferencias (estilos, colores favoritos/evitados, calzado, evitar tacones, comodidad, formalidad, siluetas,
  ocasiones, temporadas, prendas favoritas) usadas por el motor.
- Looks: favoritos, filtros, búsqueda, detalles editables, duplicar, eliminar, look manual, "usado hoy".
- Colecciones y calendario semanal local (planificar, quitar, marcar usado).
- Respaldo `.json` (formato v1, SHA-256 por foto) y restauración (combinar o reemplazar), manejo de IDs duplicados,
  archivos dañados o faltantes.
- Almacenamiento: uso de espacio, limpieza de imágenes huérfanas.

### Fase 6 — Estabilización — Pendiente
- [x] Push a GitHub habilitado.
- [ ] Obtener el primer run verde de CI.
- [ ] Corregir errores de compilación que reporte CI.
- [ ] Revisar resultados de tests en CI.
- [ ] Probar instalación con AltStore en el iPhone de la usuaria y registrar el resultado.
- [ ] Revisión de accesibilidad con VoiceOver y Dynamic Type grandes en dispositivo.
- [ ] Perfilado de memoria con armarios grandes (respaldo en memoria; considerar streaming si hay >300 prendas).
- [ ] Migración a Swift 6 language mode.

## Pendientes / ideas
- Clasificación automática de categoría (hoy manual; la app no inventa atributos).
- Respaldo en formato comprimido para armarios muy grandes.
- Widget de "outfit del día" (opcional).

## Historial de commits
| Commit | Rama | Descripción |
|---|---|---|
| `d88d064` | `claude/dreamy-hypatia-v3l33w` | chore: initialize LOOKSY iOS project (Fase 1) |
| `e52ff52` | `claude/dreamy-hypatia-v3l33w` | feat: stylist engine, collages, Pinterest, looks, backups (Fases 2–5) |

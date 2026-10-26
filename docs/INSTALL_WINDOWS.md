# Instalar LOOKSY en tu iPhone desde Windows (AltStore Classic)

Esta guía usa solo herramientas gratuitas: **GitHub Actions** (compila la app), **AltServer para Windows** y
**AltStore Classic** (firman e instalan la app con tu Apple ID gratuito). No necesitas Mac, ni Apple Developer
Program, ni servicios de firma de pago.

> ⚠️ Nunca escribas tu Apple ID ni tu contraseña en el código, en GitHub o en GitHub Actions.
> Solo se introducen en AltServer/AltStore, en tu propia computadora y tu iPhone.

---

## 1. Requisitos del iPhone

- iOS **17.0 o posterior** (LOOKSY usa SwiftData y la separación de fondo de Vision de iOS 17).
- Un Apple ID (puede ser el de siempre o uno nuevo solo para instalar apps).
- Cable USB para la primera instalación.
- Espacio libre para tus fotos de prendas.

## 2. Requisitos de Windows

- Windows 10 u 11 (64 bits).
- Conexión a internet.
- Cuenta de GitHub con acceso al repositorio `angiemarz/LOOKSY-iOS` (para descargar la IPA).

## 3. Instalar iTunes e iCloud compatibles

AltServer necesita los componentes de Apple que instalan **iTunes** e **iCloud**.

1. Si tienes iTunes o iCloud instalados desde la **Microsoft Store**, la documentación de AltStore recomienda
   desinstalarlos y usar las versiones descargadas directamente desde el sitio de Apple.
2. Descarga iTunes para Windows desde **apple.com** (enlace "Windows" de la página de descarga de iTunes)
   e iCloud para Windows desde el soporte oficial de Apple.
3. Instálalos, abre iTunes una vez y acepta los términos. Inicia sesión en iCloud con tu Apple ID si AltStore
   lo solicita en su guía vigente.

> Las versiones compatibles cambian con el tiempo. Revisa siempre las instrucciones oficiales en
> **https://altstore.io** (sección *Installing AltStore → Windows* y *FAQ*) antes de instalar.

## 4. Descargar AltServer desde su sitio oficial

1. Entra a **https://altstore.io** y descarga **AltServer para Windows** (AltStore Classic).
2. Descomprime el `.zip` y ejecuta el instalador.
3. Abre AltServer: aparece como un ícono de diamante en la bandeja del sistema (junto al reloj).
   Si Windows Defender pregunta por permisos de red, permite el acceso en redes privadas.

## 5. Conectar el iPhone

1. Conecta el iPhone con el cable USB.
2. Abre iTunes y comprueba que aparece el iPhone.
3. En iTunes, en el resumen del dispositivo, activa **"Sincronizar con este iPhone por Wi-Fi"** y pulsa *Aplicar*.
   Esto permite renovar la firma después sin cable (iPhone y PC en la misma red Wi-Fi).

## 6. Autorizar la confianza del dispositivo

- En el iPhone aparecerá **"¿Confiar en esta computadora?"** → toca **Confiar** e introduce tu código.
- Si no aparece, desconecta y vuelve a conectar el cable con el iPhone desbloqueado.

## 7. Instalar AltStore Classic en el iPhone

1. Haz clic en el ícono de AltServer en la bandeja → **Install AltStore** → elige tu iPhone.
2. Introduce tu Apple ID y contraseña **en la ventana de AltServer** (se envían solo a Apple).
3. Espera el aviso de instalación completa. AltStore aparecerá en tu pantalla de inicio.
4. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos** → toca tu Apple ID en
   "App de desarrollador" → **Confiar**.

## 8. Activar el Modo de desarrollador (iOS 16 o posterior)

1. **Ajustes → Privacidad y seguridad → Modo de desarrollador** → actívalo.
   (La opción aparece después de instalar la primera app con AltStore.)
2. El iPhone se reiniciará; al encender, confirma **Activar**.

## 9. Descargar la IPA de LOOKSY desde GitHub Actions

1. Abre `https://github.com/angiemarz/LOOKSY-iOS/actions` e inicia sesión.
2. Elige el workflow **Build iOS** y la ejecución más reciente con marca verde ✅ de la rama que quieras
   (`main` para versiones aprobadas).
   - Para lanzar una compilación manual: **Run workflow** (disponible cuando el workflow está en `main`).
3. Baja hasta **Artifacts** y descarga **LOOKSY-ipa** (es un `.zip`; los artefactos caducan a los 30 días).
4. Descomprime el `.zip`. Contiene:
   - `LOOKSY-adhoc.ipa` → **recomendado** (firma provisional ad-hoc que AltStore reemplaza por la tuya).
   - `LOOKSY-unsigned.ipa` → alternativa sin ninguna firma.
   - `BUILD_INFO.txt` → versión, commit y fecha de compilación.

> Una IPA de GitHub **no se puede instalar por sí sola**: AltStore debe firmarla con tu Apple ID.

## 10. Firmar e instalar LOOKSY con AltStore

**Opción A (desde el iPhone):**
1. Pasa `LOOKSY-adhoc.ipa` al iPhone: iCloud Drive, OneDrive, Google Drive o la carpeta compartida de iTunes,
   y guárdala en la app **Archivos**.
2. Con AltServer abierto en la PC (misma Wi-Fi o por cable), abre **AltStore → My Apps → "+"** y elige la IPA.
3. AltStore la firma con tu Apple ID y la instala.

**Opción B (desde Windows):** si tu versión de AltServer muestra **"Sideload .ipa…"** en su menú, elígela,
selecciona tu iPhone y la IPA.

## 11. Solución de errores de formato de IPA

| Problema | Qué hacer |
|---|---|
| "File is not a valid IPA" / no aparece la app | Asegúrate de haber **descomprimido** el artefacto `.zip` y de elegir el archivo `.ipa`, no el `.zip`. |
| Falla con `LOOKSY-adhoc.ipa` | Prueba con `LOOKSY-unsigned.ipa` (y viceversa). |
| "Could not find AltServer" | AltServer abierto, misma red Wi-Fi, Wi-Fi sync activado en iTunes o conecta el cable. |
| "Maximum number of apps/App IDs" | Ver límites en la sección 14; desactiva otra app en AltStore o espera a que caduque un App ID. |
| "Unable to verify app" / la app no abre | Revisa *VPN y gestión de dispositivos* → Confiar; activa el Modo de desarrollador. |
| La IPA fue compilada para simulador | No debería ocurrir: el workflow falla si el binario no es `arm64` para iOS (plataforma 2). Avísalo en un issue. |
| La app se cierra al abrir con iOS < 17 | LOOKSY requiere iOS 17. |

Si un error persiste, revisa el log del paso *Validate app bundle and package IPA* del workflow: muestra el
Bundle ID, la versión mínima de iOS, las arquitecturas y la plataforma del ejecutable.

## 12. Verificar que LOOKSY abre

1. Toca el ícono de LOOKSY.
2. Debes ver **Inicio** con el saludo y las pestañas *Inicio, Mi armario, Crear outfit, Inspiración, Mis looks*.
3. Agrega una prenda en **Mi armario → +** (iOS pedirá permiso a Fotos o Cámara).
4. Cierra la app por completo y vuelve a abrirla: la prenda debe seguir ahí.

## 13. Actualizar a una nueva versión (sin perder datos)

1. **Antes de actualizar**, crea un respaldo: *Inicio → ⚙️ Ajustes → Respaldo y restauración → Crear respaldo*
   y guárdalo en Archivos o en tu PC.
2. Descarga la nueva IPA (sección 9) y ábrela con **AltStore → My Apps → "+"**.
   AltStore reemplaza la app **conservando los datos**, porque el Bundle ID de LOOKSY es siempre
   `com.angiemarz.looksy` y usas el mismo Apple ID.
3. **No borres** LOOKSY del iPhone para actualizar: borrar la app elimina sus datos locales.

## 14. Renovar la firma y límites de la cuenta gratuita

- Con un Apple ID gratuito, las apps firmadas **caducan aproximadamente a los 7 días**.
- AltStore las renueva (**Refresh All**) cuando AltServer está abierto en tu PC y el iPhone está en la misma
  Wi-Fi (o conectado por cable). AltStore intenta renovarlas en segundo plano; ábrelo de vez en cuando.
- Si la firma caduca, LOOKSY no abrirá, **pero tus datos no se borran**: renueva con AltStore y vuelve a abrir.
- Límite de **3 apps activas** firmadas con cuenta gratuita (AltStore cuenta como una).
- Límite de **10 App IDs por semana** por Apple ID: cada app nueva consume IDs; actualizar LOOKSY reutiliza el suyo.
- Estos límites los impone Apple y pueden cambiar; consulta la FAQ de AltStore.

## 15. Proteger tus datos locales

- Todo (fotos, prendas, looks, calendario, preferencias) se guarda **solo en el iPhone**, dentro de LOOKSY.
- Haz respaldos periódicos (*Ajustes → Respaldo y restauración*). El archivo `.json` contiene tus fotos:
  guárdalo en un lugar privado. **No lo subas al repositorio** (el `.gitignore` lo bloquea).
- Si cambias de Apple ID en AltStore, el Bundle ID firmado cambia y la app se instalará como una nueva sin datos:
  restaura tu respaldo con *Restaurar desde archivo*.
- Las copias de seguridad de iCloud/iTunes del iPhone también incluyen los datos de LOOKSY.

---

### Qué está verificado y qué no

- ✅ El workflow compila para dispositivo (`iphoneos`, arm64) y valida la estructura `Payload/LOOKSY.app` de las IPA.
- ⏳ La instalación con AltStore en un iPhone físico **debe confirmarla el usuario**: no se ha probado en un dispositivo
  real desde este repositorio. Registra el resultado en `docs/PROGRESS.md`.

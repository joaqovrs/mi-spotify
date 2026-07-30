# mi spotify — Servidor de streaming de música propio

Proyecto para auto-hospedar un servicio de streaming de música (tipo Spotify, solo música)
usando una laptop antigua como servidor 24/7, **gratis**, accesible desde cualquier red WiFi
mediante una **app Android propia**.

## Objetivo
Reemplazar Spotify con una biblioteca propia servida desde casa y escuchable desde fuera de casa.

## Decisiones de arquitectura
- **Dispositivo de escucha:** Android
- **Servidor OS:** Linux en la laptop antigua (**Debian 13 "trixie" amd64, con escritorio GNOME**)
- **Backend:** **Navidrome** (servidor de música, expone la API Subsonic) — no se programa backend propio
- **Acceso remoto:** **Tailscale** (VPN privada gratis; sin abrir puertos, sin IP fija, evita CGNAT)
- **App:** **Flutter** (APK nativo Android) que consume la API Subsonic

## Arquitectura

```
Laptop vieja (Linux Debian)                                   Teléfono Android
┌─────────────────────────┐    Tailscale (VPN cifrada)    ┌──────────────────┐
│ Navidrome  (:4533)       │◄────── internet ─────────────►│ App Flutter      │
│ Carpeta música /srv/musica│                              │ Tailscale ON     │
│ Tailscale                │   API Subsonic (REST)         └──────────────────┘
└─────────────────────────┘
```

## Hardware del servidor (confirmado)
- Laptop antigua: **8 GB RAM**, CPU **64 bits** → distro: **Debian 13 amd64** (netinst, escritorio GNOME).
- GNOME en reposo usa ~1,2 GB; Navidrome ~200-400 MB. Con 8 GB sobra holgadamente.
- **Se instala con escritorio** (decisión del 29-07-2026): la laptop se usa también como PC, no solo
  como servidor headless. Implica configurar la energía en dos lugares (ver Fase 1).
- El **SSH igual se instala**: administrar desde Windows sigue siendo más cómodo que ir a la laptop.

## Estado actual
- ✅ Plan definido y aprobado. `CLAUDE.md` creado.
- ✅ **Repositorio Git + GitHub** (`joaqovrs/mi-spotify`, privado). Flujo de ramas y Pull Requests
  en funcionamiento.
- ✅ **CI activo**: workflow en `.github/workflows/ci.yml` que valida `infra/docker-compose.yml`
  en cada PR. `main` protegida por ruleset (no se puede mergear en rojo ni pushear directo).
- ✅ **Configuración de Navidrome escrita por adelantado** en `infra/docker-compose.yml`,
  lista para desplegar cuando exista el servidor.
- ✅ **Fase 1 completa (29-07-2026):** Debian 13 + GNOME instalado en la laptop. Suspensión
  desactivada (GNOME + `logind.conf` + `systemctl mask`), SSH funcionando, sistema actualizado,
  `/srv/musica` creada y Docker instalado (usuario en el grupo `docker`).
- ✅ **Fase 2 completa (29-07-2026):** repo clonado en el servidor vía **deploy key SSH**,
  `docker compose up -d` levantado y usuario admin de Navidrome creado.
- ✅ **Música cargando:** primer álbum subido por **WinSCP** (SFTP a `/srv/musica`) y reproducido
  OK en la red local. Falta subir el resto de la biblioteca.
- ✅ **Fase 3 completa (29-07-2026):** Tailscale instalado y autenticado en la Debian, IP del
  tailnet **`100.91.22.33`**, expiración de clave desactivada, app instalada en el teléfono.
  **Prueba de fuego superada:** reproducción OK desde el teléfono con el WiFi apagado (solo datos
  móviles). El backend está terminado y accesible desde cualquier red.
- 🔄 **Fase 4 en curso (30-07-2026): 6 de 7 etapas de la app terminadas y probadas en el teléfono.**
  Andando: login con doble dirección local/tailnet, sesión persistente, tema claro y oscuro,
  pantalla de inicio con carruseles reales, reproductor con segundo plano y controles en la
  notificación, buscador, cola con aleatorio y "agregar a la cola", biblioteca de favoritos y
  playlists con crear, editar y borrar.
  **Falta solo la etapa 7 (descargas offline).** Detalle en la sección Fase 4.

### Pendientes anotados
| Pendiente | Detalle |
|---|---|
| **Resto de la música** | Subir por WinSCP a `/srv/musica`, estructura `Artista/Álbum/`. |
| **Reserva DHCP** | La IP `192.168.1.194` es dinámica; fijarla en el router (`192.168.1.1`) atándola a la MAC (`d8-c0-a6-85-a6-a5`). Si cambia, la dirección local guardada en la app deja de servir y cae siempre al tailnet. |
| **Cable de red** | La laptop está por WiFi (`wlp1s0`); ethernet sería más estable para 24/7. |

### Datos del servidor
| Dato | Valor |
|---|---|
| Hostname | `mi-spotify` |
| Usuario | `mi-spotify` |
| IP local | `192.168.1.194` (⚠️ **DHCP dinámica** — pendiente reserva en el router) |
| Interfaz | `wlp1s0` (WiFi; el cable sería más estable para 24/7) |
| Acceso | `ssh mi-spotify@192.168.1.194` desde Windows |
| IP Tailscale (tailnet) | `100.91.22.33` (fija y privada — la que usa la app desde cualquier red) |
| Navidrome (red local) | `http://192.168.1.194:4533` |
| Navidrome (remoto) | `http://100.91.22.33:4533` |
| Repo en el servidor | `~/mi-spotify` (deploy key SSH, solo lectura) |

## Flujo de trabajo (CI/CD)
El proyecto se desarrolla con metodología CI/CD como práctica deliberada. **Todo cambio entra
por rama + Pull Request**, nunca directo a `main`.

```
rama nueva → commit → push → Pull Request → CI verde ✅ → merge → borrar rama → git pull
```

- **Convención de nombres** (ramas y commits): `feat:` funcionalidad, `fix:` arreglos,
  `docs:` documentación, `chore:` mantenimiento.
- **CI** (`.github/workflows/ci.yml`): corre en cada PR y en cada push a `main`. Chequeo actual:
  `docker compose -f infra/docker-compose.yml config`.
- **Protección de `main`** (Settings → Rules → Rulesets): exige PR, exige el chequeo en verde,
  bloquea force push y borrado. Sin bypass para el dueño; *required approvals* en 0 (proyecto
  de una sola persona).
- **Manual del flujo** en `docs/manual-flujo-git.pdf` — carpeta `docs/` ignorada a propósito,
  no se versiona.

### Hoja de ruta CI/CD
| Paso | Qué es | Estado |
|---|---|---|
| 1–2 | Git configurado + repo en GitHub | ✅ |
| 3 | Ramas y Pull Requests | ✅ |
| 4 | Primer workflow de CI (valida el compose) | ✅ |
| 5 | `main` protegida: el CI con poder de veto | ✅ |
| 6 | **CD**: la Debian se actualiza sola al mergear (runner self-hosted) | 🔓 desbloqueado (la laptop ya está) |
| 7 | CI de la app Flutter (`flutter analyze` + `flutter test`) | 🔓 desbloqueado (la app ya existe) |
| 8 | **CD**: APK firmado publicado en GitHub Releases al taguear versión | ⏸ necesita la app |

Los pasos 1–5 se completaron sin hardware; es el tope de lo posible antes de tener el servidor.

## Costo
Todo el software es gratuito (Debian, Navidrome, Tailscale free, Flutter). Único costo real:
electricidad de la laptop encendida 24/7. No se paga dominio ni IP fija.

---

## Fases del proyecto

### Fase 1 — Laptop como servidor Linux (con escritorio)
1. Instalar **Debian 13 amd64** desde la ISO *netinst*, marcando en *Selección de software*:
   **GNOME**, **Entorno de escritorio Debian**, **servidor SSH** y **utilidades estándar del sistema**.
2. **Evitar que se suspenda — hay que hacerlo en los dos niveles**, porque el escritorio pisa a
   systemd:
   - **GNOME (manda sobre el resto):** *Configuración → Energía* → *Apagado automático de pantalla:
     Nunca* y *Suspensión automática: Desactivada*. Además, por consola:
     `gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'` y
     `gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'`.
   - **systemd:** en `/etc/systemd/logind.conf` poner `HandleLidSwitch=ignore`,
     `HandleLidSwitchExternalPower=ignore` y `HandleLidSwitchDocked=ignore`; reiniciar
     `systemd-logind`. Rematar con
     `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`.
   - Opcional pero recomendado: desactivar el bloqueo de pantalla y activar el inicio de sesión
     automático (*Configuración → Usuarios*), para que tras un corte de luz el equipo vuelva solo
     sin que nadie escriba la contraseña.
3. SSH (`openssh-server`) queda instalado desde el instalador: administrar desde Windows con
   `ssh usuario@ip-local`.
4. `sudo apt update && sudo apt full-upgrade -y`.
5. Crear `/srv/musica` (`sudo mkdir -p /srv/musica` + `chown` al usuario) y copiar ahí la música.
   Con escritorio se puede copiar por USB arrastrando archivos en el gestor de archivos.
6. Instalar **Docker** desde el repositorio oficial de Docker y agregar el usuario al grupo `docker`.

### Fase 2 — Navidrome (backend)
- Instalar vía **Docker Compose**. Servicio en el puerto **4533**.
- ✅ El compose **ya está escrito y validado por CI** en `infra/docker-compose.yml`: apunta la
  carpeta de música (`/srv/musica:/music:ro`) y una carpeta `data` persistente.
- En el servidor: clonar el repo, `docker compose up -d` desde `infra/`.
- Crear usuario admin en `http://localhost:4533` (con escritorio se abre en el navegador de la
  propia laptop) o en `http://ip-local:4533` desde Windows, y esperar el primer escaneo.
- Después: instalar el **runner self-hosted** de GitHub Actions en la Debian → paso 6 (CD).

### Fase 3 — Acceso remoto (Tailscale) ✅ COMPLETA (29-07-2026)
Pasos ejecutados (se dejan documentados para poder repetirlos en otro nodo):

1. **Cuenta gratis** en `tailscale.com` (se entra con Google/Microsoft/GitHub). El plan libre
   permite 100 dispositivos.
2. **Instalar en la Debian** (por SSH desde Windows):
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```
   El instalador oficial detecta Debian 13 y deja configurado el repositorio apt. `tailscale up`
   imprime una **URL** `https://login.tailscale.com/a/xxxx` → abrirla en el navegador de Windows e
   iniciar sesión con la cuenta del paso 1.
3. **Anotar la IP del tailnet:** `tailscale ip -4` → devuelve `100.x.y.z`. Es fija y privada;
   es la dirección con la que la app va a conectarse desde cualquier red.
4. ⚠️ **Desactivar la expiración de la clave** (paso crítico, poco documentado): por defecto
   Tailscale desconecta cada nodo **cada 6 meses** y exige re-autenticar, lo que rompe el servidor
   sin aviso. En `login.tailscale.com/admin/machines` → máquina `mi-spotify` → menú `...` →
   **Disable key expiry**.
5. **Instalar en el teléfono:** app *Tailscale* de Play Store, misma cuenta, activar el interruptor
   (Android pide permiso de VPN).
6. **Prueba de fuego:** en el teléfono **apagar el WiFi** (solo datos móviles) y abrir
   `http://100.x.y.z:4533` en el navegador. Si carga Navidrome y reproduce, el acceso remoto
   funciona — sin abrir puertos del router ni pagar IP fija.

Mejoras opcionales una vez que ande:
- **MagicDNS:** usar `http://mi-spotify:4533` en vez de la IP numérica.
- **HTTPS:** `tailscale serve` da una URL `https://<host>.<tailnet>.ts.net` con certificado válido.

### Fase 4 — App Flutter (cliente Android) 🔄 EN CURSO
- **Auth Subsonic:** por request se manda `u`, `s` (salt), `t=md5(password+salt)`, `v=1.16.1`, `c=miSpotify`, `f=json`.
- **Endpoints:** `ping`, `getArtists`, `getArtist`, `getAlbum`, `getAlbumList2`, `search3`,
  `getCoverArt`, `stream` (URL de reproducción), `star`/`getStarred2`, `scrobble`.

#### Entorno de desarrollo (listo, 29-07-2026)
| Pieza | Detalle |
|---|---|
| Repo | `C:\dev\mi-spotify` — **movido fuera de OneDrive** (la sincronización rompe las builds de Gradle y la ruta tenía espacios) |
| Flutter SDK | `C:\dev\flutter` (3.44.8 stable), en el PATH de usuario |
| Android Studio | vía `winget install --id Google.AndroidStudio` — trae su propio JDK, no hace falta Java aparte |
| Teléfono | Redmi `24090RA29G`, Android 16 (API 36), arm64 |
| Instalación | ⚠️ HyperOS bloquea `adb install` (`INSTALL_FAILED_USER_RESTRICTED`). Workaround: `adb push` del APK a `/sdcard/Download/` e instalar desde el explorador del teléfono |

`flutter doctor` marca **Visual Studio en rojo a propósito**: es solo para apps de escritorio Windows.

#### Ciclo de trabajo de la app
Flutter **no está en el PATH del shell de Claude**, así que se invoca por ruta completa:

```powershell
cd C:\dev\mi-spotify\app
& C:\dev\flutter\bin\flutter.bat analyze
& C:\dev\flutter\bin\flutter.bat test
& C:\dev\flutter\bin\flutter.bat build apk --release
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb push build\app\outputs\flutter-apk\app-release.apk /sdcard/Download/mi-spotify.apk
```

⚠️ **`adb push` miente:** imprime `1 file pushed` incluso cuando la transferencia se corta
(pasó tres veces, con `failed to read copy response: EOF`). **Siempre comparar tamaños**
con `& $adb shell "ls -l /sdcard/Download/mi-spotify.apk"` contra el archivo local antes de
avisar que está listo. Si el teléfono desaparece, reintentar: se reconecta solo.

#### Decisiones de diseño
- Referencia visual: mucho aire, fondo blanco, tipografía pesada en títulos, tarjetas muy redondeadas.
- **Acento naranja** `#FF6B2C`. Tema claro + oscuro + seguir al sistema.
- **Poppins empaquetada en el APK** (no por CDN): la app tiene que verse igual conectada solo al tailnet.
- **Textos en español.**
- **Nada de datos falsos.** Navidrome es de un solo usuario y privado: no hay éxitos globales, ni
  listas curadas, ni playlists colaborativas. Esas secciones se reemplazan por equivalentes reales
  (agregados recientemente, tus más escuchados, al azar) con la misma presentación.
- Nav inferior: Inicio · Buscar · Biblioteca · Ajustes. Las descargas offline quedan para el final.

#### Arreglos en `AndroidManifest.xml` (no obvios)
- `<uses-permission android:name="android.permission.INTERNET"/>` — Flutter lo agrega solo en debug;
  sin esto el APK de **release** queda sin red.
- `android:usesCleartextTraffic="true"` — Android 9+ bloquea HTTP sin cifrar y Navidrome es `http://`
  puro. No es riesgo: el tráfico ya va cifrado dentro del túnel de Tailscale.

#### Etapas
| # | Qué | Estado |
|---|---|---|
| 1 | Base: cliente Subsonic, login, sesión persistente, temas, navegación | ✅ |
| 2 | Inicio con carruseles de datos reales | ✅ |
| 3 | Reproductor (`just_audio` + `audio_service`), Now Playing, mini reproductor | ✅ |
| 4 | Búsqueda (`search3`) | ✅ |
| 5 | Biblioteca: favoritos y artistas seguidos (`star`/`getStarred2`) | ✅ |
| 6 | Playlists: crear, editar, borrar | ✅ |
| 7 | Descargas offline | ⏳ siguiente |

**Extras pedidos sobre la marcha:** el mini reproductor acompaña también a las pantallas de álbum
y artista (no solo al shell de pestañas); la canción que suena se marca en las listas;
*Agregar a la cola* desde el menú `···` de cada canción y desde el AppBar del álbum; y
**deslizar una canción hacia la derecha la manda a la cola** (el gesto nunca borra la fila:
ejecuta la acción y la fila vuelve sola a su lugar).

**Aleatorio: de acción a interruptor (30-07-2026).** Al principio el *Aleatorio* era un botón
grande al lado de *Reproducir* que mezclaba la cola de una vez. **Decisión revertida a pedido:**
ahora es un **interruptor de ícono solo**, discreto, que se deja puesto:

- Encendido, el recorrido es al azar **también al saltar de canción**; apagado, la cola vuelve al
  orden del álbum o la playlist.
- Es un modo del reproductor (`setShuffleMode` de `audio_service` sobre `shuffleModeEnabled` de
  `just_audio`), así que **la cola conserva el orden original** y apagarlo no necesita recargar
  nada. Esto es lo que permite que el aleatorio conviva con reordenar la playlist.
- Cargar canciones nuevas reinicia el recorrido, así que `reproducirLista` vuelve a sortear si el
  modo está encendido. `shuffle()` deja primera a la que está sonando, por eso no corta nada.
- Con el aleatorio puesto, *Reproducir* **arranca en una canción al azar**: si empezara siempre por
  la primera, parecería que el interruptor no hace nada hasta el segundo tema.
- El estado del botón sale del propio reproductor (`playbackState.shuffleMode`), no de una variable
  aparte, así no puede quedar desfasado de lo que realmente suena.

**Playlists (etapa 6):** las listas son del servidor, no de la app (`getPlaylists`, `getPlaylist`,
`createPlaylist`, `updatePlaylist`, `deletePlaylist`). Tres cosas de la API que no son obvias:

- Subsonic manda varias canciones **repitiendo el parámetro** (`songId=1&songId=2`), no separadas
  por comas. El cliente acepta listas como valor de un parámetro para eso.
- **Quitar va por posición, no por id:** una playlist admite la misma canción repetida y por id se
  borrarían las dos.
- **Reordenar exige reescribir la lista entera** (`createPlaylist` sobre un `playlistId` que ya
  existe). `updatePlaylist` solo sabe agregar al final y quitar por índice.
- En la UI se usa **`onReorderItem`**, no `onReorder` (deprecado en Flutter 3.44): el nuevo ya
  entrega el índice de destino compensado por el hueco del elemento arrastrado.

**La cola sigue a la playlist que suena (30-07-2026):** la cola era una foto sacada al tocar
*Reproducir*, así que reordenar la playlist mientras sonaba no cambiaba nada hasta volver a darle
play. Ahora el handler recuerda **de dónde salió la cola** (`origenCola`, del tipo
`playlist:<id>`) y, cuando la playlist que se está editando es la que suena, el mismo movimiento
se aplica a la reproducción — igual que Spotify. Detalles:

- Vale para reordenar, quitar y agregar canciones.
- Se aplica **después** de que el servidor confirma, no antes: la cola no está a la vista, así que
  no hace falta el truco optimista y se evita tener que deshacer el movimiento si falla.
- Funciona igual con el aleatorio encendido, porque ese modo **no toca el orden de la cola**, solo
  el recorrido. Los índices siguen coincidiendo con la lista de la pantalla.

**Favoritos (etapa 5):** `getStarred2` es la **única** fuente de verdad. Los álbumes y canciones
que llegan de otros endpoints también traen si están marcados, pero mezclar ambas fuentes produce
incoherencias (desmarcás algo y el listado viejo lo sigue mostrando lleno). Como los ids de Subsonic
son únicos entre tipos, un solo conjunto de ids alcanza para todos los corazones. El toque actualiza
la pantalla primero y confirma contra el servidor después; si falla, revierte solo.

**Doble dirección (etapa 1):** el cliente guarda la IP local y la del tailnet y descubre sola cuál
responde — sonda la local con timeout corto (1,8 s) y cae a la remota si no contesta. Si la activa
se cae a mitad de uso, la descarta y vuelve a resolver, así salir de casa con la app abierta no la
rompe. Si el servidor **contesta pero rechaza** (contraseña mal), corta ahí en vez de seguir probando.

Estructura real:
```
app/lib/
  main.dart                          arranque + "puerta" login/app
  core/theme.dart                    paleta naranja, temas claro y oscuro
  core/subsonic_client.dart          cliente API (auth, doble dirección, URLs)
  core/auth_storage.dart             credenciales en el Keystore
  models/biblioteca.dart             Album, Cancion, Artista, Playlist, Favoritos
  services/reproductor_handler.dart  motor de audio (just_audio + audio_service)
  state/sesion_providers.dart        estado de sesión (Riverpod)
  state/tema_providers.dart          preferencia de tema
  state/biblioteca_providers.dart    inicio, búsqueda, álbumes y artistas
  state/favoritos_providers.dart     favoritos (fuente única: getStarred2)
  state/playlists_providers.dart     playlists y contenido de cada una
  state/reproductor_providers.dart   cola, progreso, origen de la cola
  ui/                                pantallas + ui/widgets/ piezas compartidas
  ui/acciones.dart                   encolar, guardar en playlist, diálogos
```

---

## Orden de ejecución
Fase 1 → Fase 2 → probar Navidrome en navegador local → Fase 3 → probar acceso remoto en
navegador (otra red) → Fase 4. **No** empezar por la app: validar backend + acceso remoto primero.

## Verificación end-to-end
1. `http://localhost:4533` en la laptop y `http://ip-local:4533` desde Windows reproducen en la red local.
2. Con el teléfono en otra red + Tailscale, `http://100.x.x.x:4533` carga Navidrome.
3. App: login valida con `ping`; reproduce en streaming; controles en notificación; funciona fuera de casa.
4. `flutter build apk --release` e instalar el APK definitivo.

## Notas
- La música la aporta el usuario (archivos en `/srv/musica`). Navidrome no descarga música.
- Backups: respaldar la carpeta `data` de Navidrome y la carpeta de música.
- Seguridad: con Tailscale, Navidrome no queda expuesto a internet; solo dispositivos del tailnet lo ven.

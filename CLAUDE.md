# Mi Music — Servidor de streaming de musica propio

Proyecto para auto-hospedar un servicio de streaming de musica (tipo Spotify, solo musica)
usando una laptop antigua como servidor 24/7, **gratis**, accesible desde cualquier red WiFi
mediante una **app Android propia**.

> **La app se llama "Mi Music"** desde el 31-07-2026. El repositorio, la carpeta local
> (`C:\dev\mi-spotify`), el hostname del servidor y el `applicationId` de Android siguen diciendo
> `mi-spotify` **a proposito**: renombrarlos obligaria a reclonar el repo, rehacer la deploy key y
> reinstalar la app como si fuera otra, perdiendo sesion y descargas. Es solo el nombre visible.

> **Idioma:** todo el texto de la app y de este documento va en **espanol neutro y sin tildes**
> (decision del usuario, 31-07-2026). Se conserva la ñ. Aplica tambien a las respuestas de Claude.

## Objetivo
Reemplazar Spotify con una biblioteca propia servida desde casa y escuchable desde fuera de casa.

## Decisiones de arquitectura
- **Dispositivo de escucha:** Android
- **Servidor OS:** Linux en la laptop antigua (**Debian 13 "trixie" amd64, con escritorio GNOME**)
- **Backend:** **Navidrome** (servidor de musica, expone la API Subsonic) — no se programa backend propio
- **Acceso remoto:** ✅ **puertos abiertos en el router + DDNS** (30-07-2026). Se dejo Tailscale.
  Decision del usuario: es una app privada, ya abrio puertos antes y prefiere no depender de una
  VPN ni de que la otra persona instale nada. Dominio `mimusic.duckdns.org`, puerto externo
  `34533`. Detalle en **Fase 5**.
- **App:** **Flutter** (APK nativo Android) que consume la API Subsonic

## Arquitectura

```
Laptop vieja (Linux Debian)          Router 192.168.1.1             Telefono Android
┌──────────────────────────┐      ┌────────────────────┐        ┌──────────────────┐
│ Navidrome  (:4533)        │◄────┤ port forward        │◄internet┤ App Flutter      │
│ Carpeta musica /srv/musica│      │ WAN:34533 → :4533   │        │ (sin VPN)        │
│ IP fija 192.168.1.194     │      └────────────────────┘        └──────────────────┘
│ cron duck.sh cada 5 min ──┼──────► DuckDNS ──► mimusic.duckdns.org
└──────────────────────────┘
```

El cliente DDNS **no corre en el router** (este HGU no tiene esa funcion): es un script con `cron`
en la propia Debian. Ver Fase 5.

## Hardware del servidor (confirmado)
- Laptop antigua: **8 GB RAM**, CPU **64 bits** → distro: **Debian 13 amd64** (netinst, escritorio GNOME).
- GNOME en reposo usa ~1,2 GB; Navidrome ~200-400 MB. Con 8 GB sobra holgadamente.
- **Se instala con escritorio** (decision del 29-07-2026): la laptop se usa tambien como PC, no solo
  como servidor headless. Implica configurar la energia en dos lugares (ver Fase 1).
- El **SSH igual se instala**: administrar desde Windows sigue siendo mas comodo que ir a la laptop.

## Estado actual
- ✅ Plan definido y aprobado. `CLAUDE.md` creado.
- ✅ **Repositorio Git + GitHub** (`joaqovrs/mi-spotify`, privado). Flujo de ramas y Pull Requests
  en funcionamiento.
- ✅ **CI activo**: workflow en `.github/workflows/ci.yml` que valida `infra/docker-compose.yml`
  en cada PR. `main` protegida por ruleset (no se puede mergear en rojo ni pushear directo).
- ✅ **Configuracion de Navidrome escrita por adelantado** en `infra/docker-compose.yml`,
  lista para desplegar cuando exista el servidor.
- ✅ **Fase 1 completa (29-07-2026):** Debian 13 + GNOME instalado en la laptop. Suspension
  desactivada (GNOME + `logind.conf` + `systemctl mask`), SSH funcionando, sistema actualizado,
  `/srv/musica` creada y Docker instalado (usuario en el grupo `docker`).
- ✅ **Fase 2 completa (29-07-2026):** repo clonado en el servidor via **deploy key SSH**,
  `docker compose up -d` levantado y usuario admin de Navidrome creado.
- ✅ **Musica cargando:** primer album subido por **WinSCP** (SFTP a `/srv/musica`) y reproducido
  OK en la red local. Falta subir el resto de la biblioteca.
- ✅ **Fase 3 completa (29-07-2026):** Tailscale instalado y autenticado en la Debian, IP del
  tailnet **`100.91.22.33`**, expiracion de clave desactivada, app instalada en el telefono.
  **Prueba de fuego superada:** reproduccion OK desde el telefono con el WiFi apagado (solo datos
  moviles). El backend esta terminado y accesible desde cualquier red.
- ✅ **Fase 4 completa (30-07-2026): las 7 etapas de la app terminadas y probadas en el telefono.**
  Login con doble direccion local/remota, sesion persistente, tema claro y oscuro, pantalla de
  inicio con carruseles reales, reproductor con segundo plano y controles en la notificacion,
  buscador, cola con aleatorio y "agregar a la cola", biblioteca de favoritos, playlists con crear,
  editar y borrar, y **descargas offline** (probado OK el 30-07-2026: se descarga, se ve la pestaña
  con caratulas y reproduce sin servidor). Detalle en la seccion Fase 4.
- ✅ **La app pasa a llamarse "Mi Music" (31-07-2026):** icono propio (nota naranja sobre fondo
  oscuro, clasico + adaptativo), login solo con usuario y contrasena, **registro de usuarios**
  desde la app contra un servicio nuevo en el servidor, y todos los textos en espanol neutro sin
  tildes. Detalle en Fase 4 y Fase 6.
- ✅ **Fase 6 completa en la red local (31-07-2026):** el servicio de registro crea usuarios
  no-admin en Navidrome. Falta abrir el puerto `34534` para que funcione desde afuera.
- ✅ **Fase 5 completa (30-07-2026):** acceso remoto migrado de Tailscale a **puerto abierto +
  DDNS**. Sin CGNAT (confirmado por `traceroute`), IP local fija `192.168.1.194`, port forward
  `WAN:34533 → 192.168.1.194:4533`, dominio **`mimusic.duckdns.org`** actualizado por `cron` cada
  5 minutos, y **Tailscale bajado**. Probado desde el telefono con WiFi apagado. Detalle y trampas
  en la seccion Fase 5.

### Pendientes anotados
| Pendiente | Detalle |
|---|---|
| **PR de descargas offline** | Rama `feat/descargas-offline` **pusheada pero sin mergear** (commit `bc177fc`). El PR no se creo porque `gh` no esta instalado en el Windows: hay que abrirlo a mano. |
| **Resto de la musica** | Subir por WinSCP a `/srv/musica`, estructura `Artista/Album/`. |
| ~~Direccion remota en la app~~ | ✅ Resuelto el 31-07-2026: las direcciones dejaron de ser campos del login y viven en `core/config.dart`. Quien tenia guardada la del tailnet queda arreglado al actualizar el APK. |
| **Cable de red** | La laptop esta por WiFi (`wlp1s0`); ethernet seria mas estable para 24/7. |
| **Token de DuckDNS expuesto** | El token quedo a la vista en una captura. El usuario decidio **no regenerarlo** (30-07-2026). Si algun dia se recrea, hay que actualizar `~/duckdns/duck.sh`. |
| **Port forward del registro** | El servicio ya corre y se probo OK en la red local. Falta la regla `WAN:34534 → 192.168.1.194:8080` (TCP) en el router para poder registrarse desde afuera. |
| **APK con todo lo nuevo** | Compilar e instalar: nombre Mi Music, icono, login simple y registro. Sin esto el telefono sigue con la version vieja. |
| **Icono del APK** | Esperando el arte definitivo (imagen nueva o archivo de Figma). Mientras tanto sigue el icono por defecto de Flutter. |

### Datos del servidor
| Dato | Valor |
|---|---|
| Hostname | `mi-spotify` |
| Usuario | `mi-spotify` |
| IP local | `192.168.1.194` — **fija, configurada en la Debian** (no reserva DHCP: el router no la ofrece) |
| Rango DHCP del router | `192.168.1.81` – `192.168.1.193` — se achico de `.198` a `.193` para dejar `.194` fuera |
| DNS | `1.1.1.1` / `8.8.8.8` (puestos a mano en NetworkManager; ver trampa en Fase 5) |
| MAC | `d8-c0-a6-85-a6-a5` |
| Interfaz | `wlp1s0` (WiFi, conexion NetworkManager llamada `Joaco`) |
| Router | `192.168.1.1` (HGU con menu `Puertos` y `Red local`; **sin** reserva DHCP ni cliente DDNS) |
| Acceso | `ssh mi-spotify@192.168.1.194` desde Windows |
| IP publica (dinamica) | `181.162.130.129` al 30-07-2026 — por eso el DDNS |
| Dominio DDNS | **`mimusic.duckdns.org`** (cuenta DuckDNS gratis) |
| Puerto externo | `34533` → interno `4533` (TCP) |
| Puerto externo del registro | `34534` → interno `8080` (TCP) — **pendiente de crear en el router** |
| Navidrome (red local) | `http://192.168.1.194:4533` |
| Navidrome (remoto) | **`http://mimusic.duckdns.org:34533`** |
| Servicio de registro | **`http://mimusic.duckdns.org:34534`** |
| Tailscale | ❌ dado de baja (`tailscale down`). IP vieja del tailnet: `100.91.22.33` |
| Repo en el servidor | `~/mi-spotify` (deploy key SSH, solo lectura) |

## Flujo de trabajo (CI/CD)
El proyecto se desarrolla con metodologia CI/CD como practica deliberada. **Todo cambio entra
por rama + Pull Request**, nunca directo a `main`.

```
rama nueva → commit → push → Pull Request → CI verde ✅ → merge → borrar rama → git pull
```

- **Convencion de nombres** (ramas y commits): `feat:` funcionalidad, `fix:` arreglos,
  `docs:` documentacion, `chore:` mantenimiento.
- **CI** (`.github/workflows/ci.yml`): corre en cada PR y en cada push a `main`. Chequeo actual:
  `docker compose -f infra/docker-compose.yml config`.
- **Proteccion de `main`** (Settings → Rules → Rulesets): exige PR, exige el chequeo en verde,
  bloquea force push y borrado. Sin bypass para el dueño; *required approvals* en 0 (proyecto
  de una sola persona).
- **Manual del flujo** en `docs/manual-flujo-git.pdf` — carpeta `docs/` ignorada a proposito,
  no se versiona.

### Hoja de ruta CI/CD
| Paso | Que es | Estado |
|---|---|---|
| 1–2 | Git configurado + repo en GitHub | ✅ |
| 3 | Ramas y Pull Requests | ✅ |
| 4 | Primer workflow de CI (valida el compose) | ✅ |
| 5 | `main` protegida: el CI con poder de veto | ✅ |
| 6 | **CD**: la Debian se actualiza sola al mergear (runner self-hosted) | 🔓 desbloqueado (la laptop ya esta) |
| 7 | CI de la app Flutter (`flutter analyze` + `flutter test`) | 🔓 desbloqueado (la app ya existe) |
| 8 | **CD**: APK firmado publicado en GitHub Releases al taguear version | ⏸ necesita la app |

Los pasos 1–5 se completaron sin hardware; es el tope de lo posible antes de tener el servidor.

## Costo
Todo el software es gratuito (Debian, Navidrome, DuckDNS, Flutter). Unico costo real:
electricidad de la laptop encendida 24/7. No se paga dominio ni IP fija.

---

## Fases del proyecto

### Fase 1 — Laptop como servidor Linux (con escritorio)
1. Instalar **Debian 13 amd64** desde la ISO *netinst*, marcando en *Seleccion de software*:
   **GNOME**, **Entorno de escritorio Debian**, **servidor SSH** y **utilidades estandar del sistema**.
2. **Evitar que se suspenda — hay que hacerlo en los dos niveles**, porque el escritorio pisa a
   systemd:
   - **GNOME (manda sobre el resto):** *Configuracion → Energia* → *Apagado automatico de pantalla:
     Nunca* y *Suspension automatica: Desactivada*. Ademas, por consola:
     `gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'` y
     `gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'`.
   - **systemd:** en `/etc/systemd/logind.conf` poner `HandleLidSwitch=ignore`,
     `HandleLidSwitchExternalPower=ignore` y `HandleLidSwitchDocked=ignore`; reiniciar
     `systemd-logind`. Rematar con
     `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`.
   - Opcional pero recomendado: desactivar el bloqueo de pantalla y activar el inicio de sesion
     automatico (*Configuracion → Usuarios*), para que tras un corte de luz el equipo vuelva solo
     sin que nadie escriba la contraseña.
3. SSH (`openssh-server`) queda instalado desde el instalador: administrar desde Windows con
   `ssh usuario@ip-local`.
4. `sudo apt update && sudo apt full-upgrade -y`.
5. Crear `/srv/musica` (`sudo mkdir -p /srv/musica` + `chown` al usuario) y copiar ahi la musica.
   Con escritorio se puede copiar por USB arrastrando archivos en el gestor de archivos.
6. Instalar **Docker** desde el repositorio oficial de Docker y agregar el usuario al grupo `docker`.

### Fase 2 — Navidrome (backend)
- Instalar via **Docker Compose**. Servicio en el puerto **4533**.
- ✅ El compose **ya esta escrito y validado por CI** en `infra/docker-compose.yml`: apunta la
  carpeta de musica (`/srv/musica:/music:ro`) y una carpeta `data` persistente.
- En el servidor: clonar el repo, `docker compose up -d` desde `infra/`.
- Crear usuario admin en `http://localhost:4533` (con escritorio se abre en el navegador de la
  propia laptop) o en `http://ip-local:4533` desde Windows, y esperar el primer escaneo.
- Despues: instalar el **runner self-hosted** de GitHub Actions en la Debian → paso 6 (CD).

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
   iniciar sesion con la cuenta del paso 1.
3. **Anotar la IP del tailnet:** `tailscale ip -4` → devuelve `100.x.y.z`. Es fija y privada;
   es la direccion con la que la app va a conectarse desde cualquier red.
4. ⚠️ **Desactivar la expiracion de la clave** (paso critico, poco documentado): por defecto
   Tailscale desconecta cada nodo **cada 6 meses** y exige re-autenticar, lo que rompe el servidor
   sin aviso. En `login.tailscale.com/admin/machines` → maquina `mi-spotify` → menu `...` →
   **Disable key expiry**.
5. **Instalar en el telefono:** app *Tailscale* de Play Store, misma cuenta, activar el interruptor
   (Android pide permiso de VPN).
6. **Prueba de fuego:** en el telefono **apagar el WiFi** (solo datos moviles) y abrir
   `http://100.x.y.z:4533` en el navegador. Si carga Navidrome y reproduce, el acceso remoto
   funciona — sin abrir puertos del router ni pagar IP fija.

Mejoras opcionales una vez que ande:
- **MagicDNS:** usar `http://mi-spotify:4533` en vez de la IP numerica.
- **HTTPS:** `tailscale serve` da una URL `https://<host>.<tailnet>.ts.net` con certificado valido.

### Fase 4 — App Flutter (cliente Android) 🔄 EN CURSO
- **Auth Subsonic:** por request se manda `u`, `s` (salt), `t=md5(password+salt)`, `v=1.16.1`, `c=miSpotify`, `f=json`.
- **Endpoints:** `ping`, `getArtists`, `getArtist`, `getAlbum`, `getAlbumList2`, `search3`,
  `getCoverArt`, `stream` (URL de reproduccion), `star`/`getStarred2`, `scrobble`.

#### Entorno de desarrollo (listo, 29-07-2026)
| Pieza | Detalle |
|---|---|
| Repo | `C:\dev\mi-spotify` — **movido fuera de OneDrive** (la sincronizacion rompe las builds de Gradle y la ruta tenia espacios) |
| Flutter SDK | `C:\dev\flutter` (3.44.8 stable), en el PATH de usuario |
| Android Studio | via `winget install --id Google.AndroidStudio` — trae su propio JDK, no hace falta Java aparte |
| Telefono | Redmi `24090RA29G`, Android 16 (API 36), arm64 |
| Instalacion | ⚠️ HyperOS bloquea `adb install` (`INSTALL_FAILED_USER_RESTRICTED`). Workaround: `adb push` del APK a `/sdcard/Download/` e instalar desde el explorador del telefono |

`flutter doctor` marca **Visual Studio en rojo a proposito**: es solo para apps de escritorio Windows.

#### Ciclo de trabajo de la app
Flutter **no esta en el PATH del shell de Claude**, asi que se invoca por ruta completa:

```powershell
cd C:\dev\mi-spotify\app
& C:\dev\flutter\bin\flutter.bat analyze
& C:\dev\flutter\bin\flutter.bat test
& C:\dev\flutter\bin\flutter.bat build apk --release
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb push build\app\outputs\flutter-apk\app-release.apk /sdcard/Download/mi-spotify.apk
```

⚠️ **`adb push` miente:** imprime `1 file pushed` incluso cuando la transferencia se corta
(paso tres veces, con `failed to read copy response: EOF`). **Siempre comparar tamaños**
con `& $adb shell "ls -l /sdcard/Download/mi-spotify.apk"` contra el archivo local antes de
avisar que esta listo. Si el telefono desaparece, reintentar: se reconecta solo.

#### Decisiones de diseño
- Referencia visual: mucho aire, fondo blanco, tipografia pesada en titulos, tarjetas muy redondeadas.
- **Acento naranja** `#FF6B2C`. Tema claro + oscuro + seguir al sistema.
- **Poppins empaquetada en el APK** (no por CDN): la app tiene que verse igual sin salida a internet.
- **Textos en espanol neutro y sin tildes** (ver la nota de idioma al principio del documento).
- **Nada de datos falsos.** Navidrome es de un solo usuario y privado: no hay exitos globales, ni
  listas curadas, ni playlists colaborativas. Esas secciones se reemplazan por equivalentes reales
  (agregados recientemente, tus mas escuchados, al azar) con la misma presentacion.
- Nav inferior: Inicio · Buscar · Biblioteca · Ajustes. Dentro de Biblioteca, las pestañas
  Playlists · Canciones · Albumes · Artistas · Descargas.

#### Arreglos en `AndroidManifest.xml` (no obvios)
- `<uses-permission android:name="android.permission.INTERNET"/>` — Flutter lo agrega solo en debug;
  sin esto el APK de **release** queda sin red.
- `android:usesCleartextTraffic="true"` — Android 9+ bloquea HTTP sin cifrar y Navidrome es `http://`
  puro. ⚠️ **Desde la Fase 5 ya no hay tunel de Tailscale que lo cubra:** el trafico (contraseña
  incluida) viaja en texto plano por internet. Asumido por el usuario; se arregla poniendo HTTPS
  con un proxy inverso, anotado como mejora opcional en Fase 5.

#### Etapas
| # | Que | Estado |
|---|---|---|
| 1 | Base: cliente Subsonic, login, sesion persistente, temas, navegacion | ✅ |
| 2 | Inicio con carruseles de datos reales | ✅ |
| 3 | Reproductor (`just_audio` + `audio_service`), Now Playing, mini reproductor | ✅ |
| 4 | Busqueda (`search3`) | ✅ |
| 5 | Biblioteca: favoritos y artistas seguidos (`star`/`getStarred2`) | ✅ |
| 6 | Playlists: crear, editar, borrar | ✅ |
| 7 | Descargas offline | ✅ |

**Extras pedidos sobre la marcha:** el mini reproductor acompaña tambien a las pantallas de album
y artista (no solo al shell de pestañas); la cancion que suena se marca en las listas;
*Agregar a la cola* desde el menu `···` de cada cancion y desde el AppBar del album; y
**deslizar una cancion hacia la derecha la manda a la cola** (el gesto nunca borra la fila:
ejecuta la accion y la fila vuelve sola a su lugar).

**Aleatorio: de accion a interruptor (30-07-2026).** Al principio el *Aleatorio* era un boton
grande al lado de *Reproducir* que mezclaba la cola de una vez. **Decision revertida a pedido:**
ahora es un **interruptor de icono solo**, discreto, que se deja puesto:

- Encendido, el recorrido es al azar **tambien al saltar de cancion**; apagado, la cola vuelve al
  orden del album o la playlist.
- Es un modo del reproductor (`setShuffleMode` de `audio_service` sobre `shuffleModeEnabled` de
  `just_audio`), asi que **la cola conserva el orden original** y apagarlo no necesita recargar
  nada. Esto es lo que permite que el aleatorio conviva con reordenar la playlist.
- Cargar canciones nuevas reinicia el recorrido, asi que `reproducirLista` vuelve a sortear si el
  modo esta encendido. `shuffle()` deja primera a la que esta sonando, por eso no corta nada.
- Con el aleatorio puesto, *Reproducir* **arranca en una cancion al azar**: si empezara siempre por
  la primera, pareceria que el interruptor no hace nada hasta el segundo tema.
- El estado del boton sale del propio reproductor (`playbackState.shuffleMode`), no de una variable
  aparte, asi no puede quedar desfasado de lo que realmente suena.

**Playlists (etapa 6):** las listas son del servidor, no de la app (`getPlaylists`, `getPlaylist`,
`createPlaylist`, `updatePlaylist`, `deletePlaylist`). Tres cosas de la API que no son obvias:

- Subsonic manda varias canciones **repitiendo el parametro** (`songId=1&songId=2`), no separadas
  por comas. El cliente acepta listas como valor de un parametro para eso.
- **Quitar va por posicion, no por id:** una playlist admite la misma cancion repetida y por id se
  borrarian las dos.
- **Reordenar exige reescribir la lista entera** (`createPlaylist` sobre un `playlistId` que ya
  existe). `updatePlaylist` solo sabe agregar al final y quitar por indice.
- En la UI se usa **`onReorderItem`**, no `onReorder` (deprecado en Flutter 3.44): el nuevo ya
  entrega el indice de destino compensado por el hueco del elemento arrastrado.

**Descargas offline (etapa 7):** el objetivo es que la app siga sirviendo con el servidor apagado
o sin red. Decisiones:

- Los archivos van al **almacenamiento privado de la app** (`getApplicationSupportDirectory`): no
  pide ningun permiso de Android, no aparecen en la galeria ni en el reproductor del sistema, y se
  limpian solos al desinstalar.
- Se baja por **`download` y no por `stream`**: `stream` puede transcodificar segun como este
  configurado el servidor, y para guardar queremos el archivo tal cual esta en `/srv/musica`. El
  nombre conserva la extension original, que viene en el campo `suffix` de la cancion.
- **Se guardan tambien los metadatos**, no solo el archivo. La pestaña Descargas tiene que poder
  listarse sin red, y pedirle los titulos a Navidrome justo cuando no se lo puede alcanzar seria
  absurdo. El indice va en `shared_preferences` como JSON: son unos kilobytes y no justifica traer
  una base de datos. `Cancion.aJson()` escribe la **misma forma que manda Subsonic**, asi
  `Cancion.desdeJson` lo relee sin un segundo formato.
- **Tambien se baja la caratula**, si no la pantalla de descargas se veria con todos los marcadores
  grises justo cuando mas se la usa. Se nombra por id de portada, no por cancion: todo un album
  comparte imagen. Al borrar, la caratula solo se elimina si no queda ningun tema que la use.
- **El indice se verifica contra el disco al leerlo.** Un archivo puede desaparecer sin que la app
  se entere; es preferible que una cancion figure como no descargada a que al tocarla no suene nada.
- **Se baja de a una.** Saturar el tunel con veinte descargas en paralelo hace que no termine
  ninguna y encima corta lo que este sonando. Si una falla, se anota el motivo y la tanda sigue.
- Enganche con el reproductor: `aMediaItem` apunta al archivo local cuando existe. Es **lo unico**
  que hace falta para que suene sin conexion, porque de ahi para abajo al reproductor le da igual
  de donde salga el audio.
- ⚠️ **Cuidado con los rebuilds:** el avance de una descarga cambia varias veces por segundo. Los
  providers derivados (`archivosDescargadosProvider`, `portadasDescargadasProvider`, etc.) miran
  `descargasProvider.select(...)` y no el estado entero; sin ese recorte, cada tick reconstruiria
  todas las portadas y filas en pantalla.
- `avisar` vive en `ui/avisos.dart` y no en `ui/acciones.dart` porque lo usan tanto las acciones
  como los widgets, y desde `acciones.dart` los imports se hacian circulares.

**La cola sigue a la playlist que suena (30-07-2026):** la cola era una foto sacada al tocar
*Reproducir*, asi que reordenar la playlist mientras sonaba no cambiaba nada hasta volver a darle
play. Ahora el handler recuerda **de donde salio la cola** (`origenCola`, del tipo
`playlist:<id>`) y, cuando la playlist que se esta editando es la que suena, el mismo movimiento
se aplica a la reproduccion — igual que Spotify. Detalles:

- Vale para reordenar, quitar y agregar canciones.
- Se aplica **despues** de que el servidor confirma, no antes: la cola no esta a la vista, asi que
  no hace falta el truco optimista y se evita tener que deshacer el movimiento si falla.
- Funciona igual con el aleatorio encendido, porque ese modo **no toca el orden de la cola**, solo
  el recorrido. Los indices siguen coincidiendo con la lista de la pantalla.

**Favoritos (etapa 5):** `getStarred2` es la **unica** fuente de verdad. Los albumes y canciones
que llegan de otros endpoints tambien traen si estan marcados, pero mezclar ambas fuentes produce
incoherencias (desmarcas algo y el listado viejo lo sigue mostrando lleno). Como los ids de Subsonic
son unicos entre tipos, un solo conjunto de ids alcanza para todos los corazones. El toque actualiza
la pantalla primero y confirma contra el servidor despues; si falla, revierte solo.

**Doble direccion (etapa 1):** el cliente guarda la direccion local y la remota y descubre sola cual
responde — sonda la local con timeout corto (1,8 s) y cae a la remota si no contesta.

**Mi Music: el login deja de pedir direcciones (31-07-2026).** Las dos direcciones eran campos del
formulario, y eso salio mal apenas cambio el acceso remoto: la app seguia con la IP del tailnet
guardada en el telefono, andaba por WiFi (entraba por la local) y fallaba con datos moviles. Un
cambio en el servidor no tiene por que obligar a cada persona a editar su login.

Ahora las direcciones son **constantes en `core/config.dart`** y el login pide solo usuario y
contrasena. Consecuencias:

- Cambiar el acceso remoto es cambiar una linea y recompilar. La doble direccion **se conserva**
  porque sigue siendo util: en casa entra directo por `192.168.1.194` sin salir a internet.
- `AuthStorage` guarda solo usuario y contrasena, y **borra las claves viejas de URL** al escribir.
  Efecto lateral bueno: quien tenia guardada la direccion del tailnet queda arreglado al
  actualizar, sin volver a iniciar sesion.

**Registro de usuarios (31-07-2026).** El login tiene un boton *No tengo cuenta, quiero crear una*
que lleva a `registro_screen.dart`: usuario, contrasena repetida y **codigo de invitacion**.

⚠️ **Por que no le pega a Navidrome directamente:** Subsonic no tiene ningun endpoint para crear
usuarios, y el de la API nativa de Navidrome (`POST /api/user`) exige un token de administrador.
Meter las credenciales de admin en el APK es publicarlas — un APK se abre con cualquier
herramienta y adentro esta todo. Por eso la app le habla a un **servicio aparte** en el servidor
(`infra/registro/`), que es el unico que conoce esas credenciales. Ver **Fase 6**.

**Textos en espanol neutro sin tildes (31-07-2026).** Decision del usuario. Se quito el voseo
(`Ingresa` → `Escribe`, `tienes` → `tienes`, `aqui` → `aqui`) y todas las tildes de `app/lib` y
`app/test`. **Se conserva la ñ**: no es una tilde y quitarla convierte "ano" en otra palabra. El
unico acento que sobrevive a proposito esta en `test/descargas_test.dart`, porque ese test
justamente verifica que `nombreSeguro` limpie los caracteres no ASCII de un nombre de archivo. Si la activa
se cae a mitad de uso, la descarta y vuelve a resolver, asi salir de casa con la app abierta no la
rompe. Si el servidor **contesta pero rechaza** (contraseña mal), corta ahi en vez de seguir probando.

Estructura real:
```
app/lib/
  main.dart                          arranque + "puerta" login/app
  core/theme.dart                    paleta naranja, temas claro y oscuro
  core/subsonic_client.dart          cliente API (auth, doble direccion, URLs)
  core/auth_storage.dart             credenciales en el Keystore
  core/descargas_storage.dart        archivos bajados + indice en shared_preferences
  models/biblioteca.dart             Album, Cancion, Artista, Playlist, Favoritos
  models/descarga.dart               cancion guardada en el telefono
  services/reproductor_handler.dart  motor de audio (just_audio + audio_service)
  state/sesion_providers.dart        estado de sesion (Riverpod)
  state/tema_providers.dart          preferencia de tema
  state/biblioteca_providers.dart    inicio, busqueda, albumes y artistas
  state/favoritos_providers.dart     favoritos (fuente unica: getStarred2)
  state/playlists_providers.dart     playlists y contenido de cada una
  state/descargas_providers.dart     cola de descarga, progreso, lo guardado
  state/reproductor_providers.dart   cola, progreso, origen de la cola
  core/config.dart                   direcciones fijas del servidor y del registro
  core/registro_client.dart          cliente del servicio de registro
  ui/registro_screen.dart            crear cuenta con codigo de invitacion
  ui/widgets/marca.dart              logo y cartel de error, compartidos login/registro
  ui/                                pantallas + ui/widgets/ piezas compartidas
  ui/acciones.dart                   encolar, guardar en playlist, dialogos
  ui/acciones_descarga.dart          descargar y borrar del telefono
  ui/avisos.dart                     el aviso compartido (rompe un ciclo de imports)
```

### Fase 5 — Acceso remoto por puertos abiertos ✅ COMPLETA (30-07-2026)

**Decision del usuario (30-07-2026): se deja Tailscale y se pasa a abrir puertos en el router.**
Motivo: es una app privada, ya abrio puertos antes sin problemas y prefiere no depender de una VPN
ni de que la otra persona tenga que instalar nada. **La decision esta tomada y reafirmada — no hace
falta volver a discutirla ni advertir sobre ella.**

Lo ejecutado, en orden:

**Paso 0 — Confirmar que el ISP no usa CGNAT.** Va primero porque con CGNAT abrir puertos
**no puede funcionar**. Se intento comparar la IP WAN del router con `curl -4 ifconfig.me`, pero
**este HGU no muestra la IP WAN en ninguna pantalla**. Se resolvio con `traceroute`, que responde
lo mismo sin depender del router:

```bash
curl -4 https://ifconfig.me; echo      # → 181.162.130.129   (el `echo` hace falta: no manda \n)
traceroute -n -m 5 8.8.8.8
```

El veredicto esta en el **salto 2**: salio `181.162.128.1`, una IP **publica del mismo bloque** que
la propia → el router tiene la IP publica puesta en su WAN, no hay CGNAT. ⚠️ Los `10.50.3.x` de los
saltos 3 y 4 **no son CGNAT**: son el backbone interno del ISP y aparecen *despues* de la IP
publica. CGNAT seria un `100.64.x` – `100.127.x` **en el salto 2**.

**Paso 1 — IP local fija.** El plan decia "reserva DHCP", pero **este router no tiene esa funcion**
(la pantalla *Red local* solo permite editar el rango). Se hizo al reves, y queda mejor porque no
depende del router:

1. En el router, achicar el rango: *Direccion IP fin rango* de `192.168.1.198` a **`192.168.1.193`**,
   para que `.194` quede fuera de lo que el DHCP reparte y nadie la reciba por accidente.
2. En la Debian, IP manual por **Configuracion → Wi-Fi → ⚙ → IPv4 → Manual**: `192.168.1.194`,
   mascara `255.255.255.0`, puerta `192.168.1.1`. La tabla de GNOME muestra **una fila extra en
   blanco** (para una segunda IP) — hay que dejarla vacia o el boton *Aplicar* no se habilita.

**Paso 2 — Port forward.** Menu **Puertos** del router: TCP, externo **`34533`** → `192.168.1.194`
interno **`4533`**. El puerto externo se eligio distinto y alto a proposito: `4533` es conocido y
lo barren los escaneres automaticos.

**Paso 3 — DDNS.** La IP publica es dinamica, asi que hace falta un nombre fijo. El router **no
trae cliente DDNS**, asi que corre en la Debian. Dominio **`mimusic.duckdns.org`** (DuckDNS, gratis):

```bash
mkdir -p ~/duckdns
cat > ~/duckdns/duck.sh <<'EOF'
echo url="https://www.duckdns.org/update?domains=mimusic&token=<TOKEN>&ip=" | curl -k -o ~/duckdns/duck.log -K -
EOF
chmod 700 ~/duckdns/duck.sh
~/duckdns/duck.sh && cat ~/duckdns/duck.log     # → OK
crontab -e   # */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

En `domains=` va **solo el subdominio**, sin `.duckdns.org`. El `&ip=` vacio no es un error: le
dice a DuckDNS que use la IP desde la que llega el pedido.

**Paso 4 — Cambiar la direccion en la app.** ✅ **No hace falta tocar codigo.** La app ya guarda dos
direcciones y sonda cual responde; solo se pone en el campo remoto
`http://mimusic.duckdns.org:34533`. El manifiesto ya trae `usesCleartextTraffic="true"`.

**Paso 5 — Verificado** desde el telefono con WiFi y Tailscale apagados: Navidrome carga por
`http://181.162.130.129:34533` y por el dominio.

**Paso 6 — Tailscale dado de baja** con `sudo tailscale down`. Para que no vuelva solo tras un
reinicio: `sudo systemctl disable --now tailscaled`.

#### ⚠️ Trampa que costo una hora: Tailscale se queda con el DNS

Al bajar Tailscale la Debian dejo de resolver nombres (`curl: (6) Could not resolve host`), aunque
`ping 1.1.1.1` seguia andando — señal inequivoca de que lo roto es el DNS, no la conexion.

Son **dos causas encadenadas**:

1. Tailscale habia reescrito `/etc/resolv.conf` con su MagicDNS (`nameserver 100.100.100.100`), y
   el archivo lo declara en el encabezado: `# Generated by tailscale`.
2. Al pasar la interfaz a **IPv4 manual**, NetworkManager se quedo **sin ningun DNS que escribir**:
   `resolv.conf` volvio a ser suyo pero quedo de 30 bytes, solo el comentario, sin `nameserver`.

Arreglo (observa que el `NAME` de la conexion es el del WiFi, aqui `Joaco`):

```bash
CON=$(nmcli -t -f NAME,DEVICE connection show --active | grep ':wlp1s0$' | cut -d: -f1)
sudo nmcli connection modify "$CON" ipv4.dns "1.1.1.1,8.8.8.8" ipv4.ignore-auto-dns yes
sudo nmcli device reapply wlp1s0      # `reapply` NO corta el SSH; `connection up` si
```

**Moraleja:** al poner IP manual, el DNS **no se hereda** — hay que cargarlo explicitamente en el
mismo paso, o la maquina queda con internet pero sin poder resolver un solo nombre.

Mejoras opcionales:
- **HTTPS** con un proxy inverso (Caddy saca el certificado solo) sobre el dominio DDNS, para que
  la contraseña no viaje en texto plano. Requiere abrir tambien el 80/443 para el desafio ACME.
- **Fail2ban** sobre el log de Navidrome contra intentos de login repetidos.

### Fase 6 — Servicio de registro de usuarios ✅ FUNCIONANDO EN LA RED LOCAL (31-07-2026)

Para que alguien sin cuenta pueda crearse una desde la app, sin que el dueño tenga que entrar a
Navidrome cada vez.

**El problema.** Navidrome no tiene registro publico. La unica forma de crear un usuario es
`POST /api/user` de su API nativa, y eso pide un token que sale de iniciar sesion **como
administrador**. Si esas credenciales viajan dentro del APK, cualquiera que lo descargue puede
sacarlas y quedarse con el control del servidor. No es un riesgo teorico: descompilar un APK es
arrastrar un archivo a una herramienta.

**La solucion.** Un servicio propio en la Debian (`infra/registro/servidor.py`) que guarda las
credenciales de admin del lado del servidor y expone **un solo verbo**: crear un usuario comun.

| Decision | Por que |
|---|---|
| `isAdmin` clavado en `False` en el codigo, no leido de la peticion | Es la unica linea que impide que este endpoint fabrique administradores. |
| Solo crea: no lista, no borra, no modifica | Cuanto menos hace, menos hay que auditar. |
| Codigo de invitacion obligatorio | Sin esto se registra cualquiera que descubra el puerto. |
| `hmac.compare_digest` para comparar el codigo | El `==` normal corta en la primera letra distinta y eso filtra el codigo caracter por caracter midiendo tiempos. |
| Freno de 5 intentos fallidos por IP cada 10 minutos | El codigo es un solo valor y el puerto esta abierto a internet: sin freno se saca a fuerza bruta. |
| Solo biblioteca estandar de Python | La imagen es `python:3.12-alpine` pelada, sin build ni `requirements.txt` que mantener. |
| Volumen montado `:ro` | El servicio nunca escribe en disco. |

**Contrato:** `POST /registro` con `{usuario, password, invitacion}` → `201` si salio bien;
`401` codigo invalido, `409` usuario tomado, `429` demasiados intentos, `503` Navidrome no
responde. Tambien hay `GET /salud`.

**Despliegue (pendiente):**

1. En la Debian, dentro de `~/mi-spotify`:
   ```bash
   git pull
   cp infra/.env.ejemplo infra/.env
   nano infra/.env          # usuario y clave de admin de Navidrome + codigo de invitacion
   docker compose -f infra/docker-compose.yml up -d
   docker compose -f infra/docker-compose.yml logs -f registro
   ```
   Tiene que decir `[registro] escuchando en el puerto 8080`. Si faltan variables **no levanta a
   proposito**: un servicio que arranca bien y falla recien cuando alguien lo usa es peor que uno
   que no arranca.
2. Probar en la red local antes de abrir nada:
   ```bash
   curl -s http://192.168.1.194:8080/salud
   curl -s -X POST http://192.168.1.194:8080/registro \
     -H 'Content-Type: application/json' \
     -d '{"usuario":"prueba","password":"prueba123","invitacion":"EL_CODIGO"}'
   ```
3. **Segundo port forward** en el router: TCP `34534` → `192.168.1.194:8080`.
4. Verificar desde el telefono con datos moviles: `http://mimusic.duckdns.org:34534/salud`.

✅ **Probado el 31-07-2026 en la red local.** El `curl` del paso 2 devolvio `{"ok": true}` y el
usuario aparecio en `Settings → Users` de Navidrome **sin la marca de admin**. Con eso quedan
confirmados los nombres de campo de la API nativa (`userName`, `name`, `password`, `isAdmin`), que
eran la parte incierta: estan tomados de Navidrome 0.63.2.

Falta solo el **paso 3 (port forward `34534`)** para que se pueda usar desde afuera.

⚠️ **Docker congela las variables de entorno al crear el contenedor.** Editar `infra/.env` con el
servicio ya levantado no cambia nada: hay que correr `docker compose up -d --force-recreate`. Esto
costo una vuelta en la primera prueba, porque el sintoma es engañoso — el servicio responde bien,
pero rechaza el codigo de invitacion correcto.

El **codigo de invitacion no se documenta aqui a proposito**: vive en `infra/.env`, que esta en el
`.gitignore` justamente para que estos valores no lleguen a GitHub. Claude lo tiene anotado en su
memoria local del proyecto.

**Freno anti-fuerza-bruta:** 5 intentos fallidos por IP bloquean 10 minutos. El contador vive en
memoria, asi que `docker compose restart registro` lo limpia si molesta durante las pruebas.

### Multiusuario (respondido el 30-07-2026, actualizado el 31-07-2026)

**Varias personas pueden usar la app con sus propias playlists sin tocar una linea de codigo.**
Navidrome es multiusuario y la app se autentica en **cada request** con las credenciales de quien
inicio sesion. Son **por usuario** en Navidrome: playlists, favoritos (`star`/`getStarred2`) y
conteos de reproduccion — o sea "Tus mas escuchados" y "Vuelve a escuchar" son de cada uno. Las
credenciales viven en el Keystore de cada telefono, asi que cada instalacion es independiente.

Desde la **Fase 6** cada persona se crea la cuenta sola desde la app con el codigo de invitacion,
asi que ya no hace falta crear usuarios a mano — aunque sigue siendo posible desde
`Settings → Users` de Navidrome, **sin marcar admin**. La biblioteca de musica si es compartida:
todos ven lo mismo de `/srv/musica`.

Unico detalle conocido: `getPlaylists` de Subsonic devuelve las propias **mas las marcadas como
publicas** por cualquier usuario. Las que crea la app salen privadas (default de Navidrome), pero si
alguien marca una como publica desde la web, aparece para todos y **la app no muestra de quien es**.
Si llega a molestar, se arregla con un cartelito de "compartida por X" en `FilaPlaylist`.

---

## Orden de ejecucion
Fase 1 → Fase 2 → probar Navidrome en navegador local → Fase 3 → probar acceso remoto en
navegador (otra red) → Fase 4 → Fase 5 (migracion a puertos) → **Fase 6 (registro de usuarios)**.
Las fases 1 a 5 estan hechas; la 6 esta escrita y falta desplegarla.
La Fase 3 (Tailscale) quedo reemplazada por la Fase 5; se deja documentada por si hiciera falta
volver atras.

## Verificacion end-to-end
1. `http://localhost:4533` en la laptop y `http://ip-local:4533` desde Windows reproducen en la red local.
2. Con el telefono en otra red (datos moviles, **sin Tailscale**),
   `http://mimusic.duckdns.org:34533` carga Navidrome.
3. App: login valida con `ping`; reproduce en streaming; controles en notificacion; funciona fuera de casa.
4. Descargas: bajar un album, cortar la red y verificar que la pestaña Descargas se ve con caratulas
   y reproduce.
5. Registro: desde *No tengo cuenta, quiero crear una*, crear un usuario con el codigo de
   invitacion y entrar con el. En Navidrome tiene que aparecer en `Settings → Users`
   **sin la marca de admin**, y con sus playlists y favoritos vacios.
6. `flutter build apk --release` e instalar el APK definitivo.

## Notas
- La musica la aporta el usuario (archivos en `/srv/musica`). Navidrome no descarga musica.
- Backups: respaldar la carpeta `data` de Navidrome y la carpeta de musica.
- Exposicion: desde la **Fase 5** Navidrome esta publicado en internet detras del puerto `34533`
  del router; el control de acceso es el login de Navidrome. Decision tomada y reafirmada por el
  usuario — esta asumido, no hace falta volver sobre el tema.
- Si algun dia el acceso remoto deja de andar de golpe, el sospechoso numero uno es **la IP publica
  cambio y el `cron` de DuckDNS no corrio**. Se chequea con `cat ~/duckdns/duck.log` (tiene que
  decir `OK`) y `getent hosts mimusic.duckdns.org` contra `curl -4 ifconfig.me; echo`.

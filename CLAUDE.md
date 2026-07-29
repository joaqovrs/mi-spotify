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
- ⏳ **Siguiente paso: Fase 4 (app Flutter)** — el MVP del cliente Android.

### Pendientes anotados
| Pendiente | Detalle |
|---|---|
| **Commits del repo** | `CLAUDE.md` está modificado **sin commitear**, en la rama `docs/estado-cicd`, que además tiene un PR abierto sin mergear. Definir si se basa una rama nueva en `main` o se cierra primero ese PR. |
| **Resto de la música** | Subir por WinSCP a `/srv/musica`, estructura `Artista/Álbum/`. |
| **Reserva DHCP** | La IP `192.168.1.194` es dinámica; fijarla en el router (`192.168.1.1`) atándola a la MAC. |
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
| 7 | CI de la app Flutter (`flutter analyze` + `flutter test`) | ⏸ necesita la app |
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

### Fase 4 — App Flutter (cliente Android)
- Entorno: Flutter SDK + Android Studio en Windows; probar en teléfono físico.
- Paquetes clave: `just_audio` (streaming), `audio_service` (segundo plano/notificación),
  `dio`/`http`, `crypto` (auth md5), `riverpod`, `cached_network_image`, `flutter_secure_storage`.
- **Auth Subsonic:** por request se manda `u`, `s` (salt), `t=md5(password+salt)`, `v=1.16.1`, `c=miSpotify`, `f=json`.
- **Endpoints:** `ping`, `getArtists`, `getArtist`, `getAlbum`, `getAlbumList2`, `search3`,
  `getCoverArt`, `stream` (URL de reproducción), `star`/`getStarred2`, `scrobble`.
- **MVP:** login → explorar biblioteca → reproducir con cola → segundo plano → búsqueda.

Estructura Flutter propuesta:
```
lib/
  main.dart
  core/subsonic_client.dart   # cliente API (auth, endpoints, URLs)
  core/auth_storage.dart      # credenciales con secure_storage
  models/                     # Artist, Album, Song
  services/audio_player_handler.dart  # just_audio + audio_service
  state/                      # providers Riverpod
  ui/                         # login, home, library, album, search, player, mini_player
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

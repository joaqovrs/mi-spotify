# mi spotify — Servidor de streaming de música propio

Proyecto para auto-hospedar un servicio de streaming de música (tipo Spotify, solo música)
usando una laptop antigua como servidor 24/7, **gratis**, accesible desde cualquier red WiFi
mediante una **app Android propia**.

## Objetivo
Reemplazar Spotify con una biblioteca propia servida desde casa y escuchable desde fuera de casa.

## Decisiones de arquitectura
- **Dispositivo de escucha:** Android
- **Servidor OS:** Linux en la laptop antigua (**Debian 12**, headless)
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
- Laptop antigua: **8 GB RAM**, CPU **64 bits** → distro: **Debian 12 amd64** (netinst, headless).
- 8 GB es de sobra para Debian headless + Navidrome.

## Estado actual
- ✅ Plan definido y aprobado. `CLAUDE.md` creado.
- ✅ **Repositorio Git + GitHub** (`joaqovrs/mi-spotify`, privado). Flujo de ramas y Pull Requests
  en funcionamiento.
- ✅ **CI activo**: workflow en `.github/workflows/ci.yml` que valida `infra/docker-compose.yml`
  en cada PR. `main` protegida por ruleset (no se puede mergear en rojo ni pushear directo).
- ✅ **Configuración de Navidrome escrita por adelantado** en `infra/docker-compose.yml`,
  lista para desplegar cuando exista el servidor.
- ⏳ **Siguiente paso:** instalar **Debian 12 amd64** (sin escritorio; marcar solo *SSH server* +
  *standard system utilities*; usuario propio; red por cable si es posible).
- Al retomar, tras iniciar sesión en Debian: conectar por SSH desde Windows → desactivar
  suspensión al cerrar tapa → `apt update && upgrade` → crear `/srv/musica` → Fase 2 (Navidrome).

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
| 6 | **CD**: la Debian se actualiza sola al mergear (runner self-hosted) | ⏸ necesita la laptop |
| 7 | CI de la app Flutter (`flutter analyze` + `flutter test`) | ⏸ necesita la app |
| 8 | **CD**: APK firmado publicado en GitHub Releases al taguear versión | ⏸ necesita la app |

Los pasos 1–5 se completaron sin hardware; es el tope de lo posible antes de tener el servidor.

## Costo
Todo el software es gratuito (Debian, Navidrome, Tailscale free, Flutter). Único costo real:
electricidad de la laptop encendida 24/7. No se paga dominio ni IP fija.

---

## Fases del proyecto

### Fase 1 — Laptop como servidor Linux
1. Instalar **Debian 12** headless (sin escritorio).
2. Evitar suspensión al cerrar la tapa: en `/etc/systemd/logind.conf` poner
   `HandleLidSwitch=ignore` y `HandleLidSwitchExternalPower=ignore`; luego reiniciar `systemd-logind`.
3. Habilitar SSH (`openssh-server`) para administrar desde el PC Windows.
4. `sudo apt update && sudo apt upgrade -y`.
5. Copiar la música a `/srv/musica`.

### Fase 2 — Navidrome (backend)
- Instalar vía **Docker Compose**. Servicio en el puerto **4533**.
- ✅ El compose **ya está escrito y validado por CI** en `infra/docker-compose.yml`: apunta la
  carpeta de música (`/srv/musica:/music:ro`) y una carpeta `data` persistente.
- En el servidor: clonar el repo, `docker compose up -d` desde `infra/`.
- Crear usuario admin en `http://ip-local:4533` y esperar el primer escaneo.
- Después: instalar el **runner self-hosted** de GitHub Actions en la Debian → paso 6 (CD).

### Fase 3 — Acceso remoto (Tailscale)
- Cuenta gratis en Tailscale; instalar en laptop (`tailscale up`) y en el teléfono (misma cuenta).
- Acceder por la IP `100.x.x.x` de la laptop desde cualquier red.
- Opcional: HTTPS con `tailscale serve` (URL `https://<host>.<tailnet>.ts.net`).

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
1. `http://ip-local:4533` reproduce en la red local.
2. Con el teléfono en otra red + Tailscale, `http://100.x.x.x:4533` carga Navidrome.
3. App: login valida con `ping`; reproduce en streaming; controles en notificación; funciona fuera de casa.
4. `flutter build apk --release` e instalar el APK definitivo.

## Notas
- La música la aporta el usuario (archivos en `/srv/musica`). Navidrome no descarga música.
- Backups: respaldar la carpeta `data` de Navidrome y la carpeta de música.
- Seguridad: con Tailscale, Navidrome no queda expuesto a internet; solo dispositivos del tailnet lo ven.

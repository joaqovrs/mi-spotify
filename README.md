\# mi-spotify



Servidor de música propio y autohospedado, para reemplazar Spotify con una

biblioteca personal accesible desde cualquier red.



\## Cómo funciona



```

Laptop vieja (Debian)                          Teléfono Android

┌──────────────────────┐                      ┌──────────────┐

│ Navidrome  (:4533)   │◄─── Tailscale ──────►│ App Flutter  │

│ /srv/musica          │      (VPN)           └──────────────┘

└──────────────────────┘

```



\- \*\*Navidrome\*\* — servidor de música que expone la API Subsonic.

\- \*\*Tailscale\*\* — VPN privada para escuchar fuera de casa, sin abrir puertos ni pagar IP fija.

\- \*\*App Flutter\*\* — cliente Android propio que consume la API.



\## Estado



En desarrollo. El detalle del plan y las fases está en \[CLAUDE.md](CLAUDE.md).



\## Costo



Todo el software es gratuito. El único gasto real es la electricidad de la

laptop encendida 24/7.


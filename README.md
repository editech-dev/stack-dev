# stack-dev — Entorno Portable, Seguro y Auto-Actualizable para Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Repositorio de aprovisionamiento **idempotente** (*"si no está instalado, instálalo desde su fuente oficial; si ya está instalado, alínealo y protégelo"*) diseñado para Ubuntu / Debian Linux.

Permite replicar en minutos todo el stack de desarrollo móvil, web, backend e IA en un PC recién formateado o nuevo, con **blindaje contra ataques de *Supply-Chain*** y **actualizaciones diarias desatendidas**.

---

## Inicio Rápido (en un PC nuevo o recién formateado)

```bash
git clone https://github.com/editech-dev/stack-dev.git ~/stack-dev
cd ~/stack-dev

# Opcional: simular primero qué está instalado y qué falta sin tocar nada
./bootstrap.sh --dry-run

# Instalar lo faltante, aplicar blindajes y activar auto-actualizaciones diarias
./bootstrap.sh
```

*(Si en ese equipo nuevo tu shell por defecto aún no es Zsh, cámbiala una sola vez con `chsh -s $(which zsh)` y reinicia sesión. Tus alias o funciones privadas locales pueden colocarse en `~/.zshrc.local` sin afectar el repositorio).*

---

## Qué Instala y Configura `bootstrap.sh`

| Categoría | Componentes | Método / Estrategia |
| :--- | :--- | :--- |
| **Java & Build** | **OpenJDK LTS** (`default-jdk`), `clang`, `cmake`, `ninja`, `libgtk-3-dev` | Una única versión coherente (`java` == `javac`) gestionada por `apt` + `unattended-upgrades`. |
| **Móvil** | **Android Studio Stable** (`/opt/android-studio`), **Android SDK** (`adb`, `emulator`, `cmdline-tools`), **Flutter Stable**, **`scrcpy`** | Verificación criptográfica **SHA-256** contra el XML oficial de Google; sin requerir `sudo` para actualizarse. |
| **JS / TS** | **Node.js LTS** (`nvm`), **`npm`**, **`pnpm`** standalone, **Bun**, **Deno** | `vercel` y `supabase` como únicos CLIs globales en `pnpm` (con tokens de acceso aislados por proyecto). |
| **Python** | **`uv`** + soporte automático si existe `Anaconda3` | Entornos aislados ultrarrápidos sin contaminar el Python del sistema. |
| **Datos & Contenedores** | **DBeaver CE** + **Docker Engine** | DBeaver conectado a su repositorio firmado GPG y auto-actualización diaria; Docker para correr runtimes sensibles (como PHP) con cero huella en el host. |
| **Agentes CLI** | **`agy`** (Antigravity CLI), **`opencode`**, **`claude`**, **`codex`** | Instalaciones standalone oficiales actualizadas automáticamente todos los días. |

---

## Seguridad y Blindaje Activo

1. **Escudo Triple de 24 horas contra *Supply-Chain***:
   Bloquea automáticamente versiones de paquetes publicadas hace menos de 24 horas (frenando campañas de malware *zero-day* recién subidas a registros públicos):
   - `~/.npmrc` → `min-release-age=1` *(1 día)* + `audit=true`
   - `~/.config/pnpm/rc` → `minimum-release-age=1440` *(1440 minutos)* + `ignore-scripts=true`
   - `~/.bunfig.toml` → `minimumReleaseAge = 86400` *(86400 segundos)*
2. **Aislamiento Cero-Huella para Runtimes Críticos (ej. PHP)**:
   Nunca se instalan demonios como `php-fpm` o `apache2` en el sistema anfitrión. Para pruebas puntuales usa contenedores efímeros:
   ```bash
   docker run --rm -v "$PWD":/app -w /app php:8.4-cli php -v
   ```
3. **Deduplicación Nativa de `PATH`**:
   `config/zshrc` activa `typeset -U path PATH fpath FPATH` y detecta rutas dinámicamente (`$HOME` y arquitectura del CPU) sin quemar nombres de usuario.

---

## Comandos Incluidos en `~/.local/bin`

- **`dev-check`**: Panel de auditoría instantánea (versiones, rutas únicas, coherencia `java == javac`, estado de los 3 escudos de 24h, revisión de versión de Gradle del proyecto actual y estado del temporizador automático).
- **`dev-update`**: Actualiza manualmente todo el stack (`apt`, `snap`, Node LTS, `npm`, `pnpm` + `vercel`/`supabase`, Bun, Deno, `uv`, Flutter, Android Studio, Android SDK y los 4 CLIs).
- **`dev-update --auto`**: Modo silencioso ejecutado una vez al día por `systemd --user` (`dev-update.timer` con `Persistent=true`), con registro en `~/.local/state/dev-update.log` y notificación de escritorio al finalizar.
- **`update-android-studio`**: Comprueba (`--check`), instala (`--install`) o actualiza Android Studio Stable validando su hash SHA-256 oficial, posponiendo la actualización si detecta que tienes el IDE abierto.

---

## Estructura del Repositorio

```text
stack-dev/
├── LICENSE                            # Licencia MIT (editech-dev)
├── README.md                          # Documentación general
├── bootstrap.sh                       # Instalador maestro idempotente (--dry-run soportado)
├── bin/
│   ├── dev-check                      # Auditoría de salud y seguridad del entorno
│   ├── dev-update                     # Actualizador unificado (manual y --auto)
│   └── update-android-studio          # Gestor criptográfico SHA-256 de Android Studio
└── config/
    ├── npmrc                          # Política de seguridad npm (24h)
    ├── pnpmrc.template                # Política de seguridad pnpm (24h + ignore-scripts)
    ├── bunfig.toml                    # Política de seguridad Bun (24h)
    ├── zshrc                          # Perfil Zsh portable y deduplicado
    ├── bashrc.snippet                 # Integración equivalente para Bash
    └── systemd/
        ├── dev-update.service         # Unidad systemd de usuario
        └── dev-update.timer           # Programador diario persistente
```

---

## Herramientas y Créditos

Arquitectura, automatización y blindaje diseñados y construidos utilizando la herramienta **Google Antigravity**.

## Licencia

Distribuido bajo la licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.  
Copyright © 2026 [editech-dev](https://github.com/editech-dev).

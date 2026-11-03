#!/usr/bin/env bash
# ==============================================================================
# stack-dev | Bootstrap Idempotente para Ubuntu / Debian Linux
# Lógica: "Si no está instalado, instálalo con origen oficial; si ya está, alínealo"
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run|--check|-n) DRY_RUN=true ;;
    --help|-h)
      echo "Uso: ./bootstrap.sh [--dry-run]"
      echo "  (sin flags)  Instala cualquier componente faltante, aplica blindajes y activa auto-updates."
      echo "  --dry-run    Solo inspecciona qué componentes ya están instalados y cuáles se instalarían."
      exit 0
      ;;
  esac
done

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }
present() { echo -e "  ${GREEN}✔ Ya instalado:${NC} $*"; }
missing() { echo -e "  ${YELLOW}+ Por instalar:${NC} $*"; }

if [ "$(id -u)" -eq 0 ]; then
  echo "Error: ejecuta ./bootstrap.sh con tu usuario normal (no como root); el script pedirá sudo solo cuando sea necesario."
  exit 1
fi

mkdir -p "$HOME/.local/bin" "$HOME/.config/pnpm" "$HOME/.config/systemd/user" "$HOME/.local/state"
export PNPM_HOME="$HOME/.local/share/pnpm"
export BUN_INSTALL="$HOME/.bun"
export DENO_INSTALL="$HOME/.deno"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PNPM_HOME/bin:$BUN_INSTALL/bin:$DENO_INSTALL/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$HOME/flutter/bin:$PATH"

echo -e "${BOLD}${GREEN}=== Aprovisionamiento y Blindaje de Stack de Desarrollo (stack-dev) ===${NC}"
[ "$DRY_RUN" = true ] && echo -e "${YELLOW}(Modo simulación --dry-run: no se realizarán cambios en el sistema)${NC}"

# ------------------------------------------------------------------------------
# 1. Paquetes base del sistema, OpenJDK LTS (default-jdk), GTK3 y Unattended-Upgrades
# ------------------------------------------------------------------------------
info "1/11 Paquetes base del sistema, OpenJDK LTS y toolchain nativo (apt)"
APT_PACKAGES=(
  curl wget git zsh unzip xz-utils zip rsync jq ca-certificates gnupg
  unattended-upgrades default-jdk clang cmake ninja-build pkg-config libgtk-3-dev
)
MISSING_APT=()
for pkg in "${APT_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING_APT+=("$pkg")
  fi
done

if [ "${#MISSING_APT[@]}" -eq 0 ]; then
  present "Todos los paquetes base, OpenJDK LTS y dependencias Linux de Flutter"
else
  missing "Paquetes apt: ${MISSING_APT[*]}"
  if [ "$DRY_RUN" = false ]; then
    sudo apt-get update
    sudo apt-get install -y "${MISSING_APT[@]}"
  fi
fi

# ------------------------------------------------------------------------------
# 2. Docker (para aislamiento cero-huella de PHP, bases de datos y pruebas)
# ------------------------------------------------------------------------------
info "2/11 Docker (aislamiento seguro de contenedores)"
if command -v docker >/dev/null 2>&1; then
  present "Docker ($(docker --version | head -n1))"
else
  missing "Docker Engine (docker.io + docker-compose-v2)"
  if [ "$DRY_RUN" = false ]; then
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-v2
    sudo usermod -aG docker "$USER" || true
  fi
fi

# ------------------------------------------------------------------------------
# 3. DBeaver CE + Repositorio Oficial + Auto-Actualización Diaria
# ------------------------------------------------------------------------------
info "3/11 DBeaver Community Edition + Auto-Update APT"
if dpkg -s dbeaver-ce >/dev/null 2>&1 && [ -f /etc/apt/sources.list.d/dbeaver.list ] && [ -f /etc/apt/apt.conf.d/52dbeaver-unattended ]; then
  present "DBeaver CE ($(dpkg-query -W -f='${Version}' dbeaver-ce)) con repositorio oficial y unattended-upgrades"
else
  missing "DBeaver CE + repositorio firmado dbeaver.io + regla unattended-upgrades"
  if [ "$DRY_RUN" = false ]; then
    curl -fsSL https://dbeaver.io/debs/dbeaver.gpg.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/dbeaver.gpg
    sudo chmod 644 /usr/share/keyrings/dbeaver.gpg
    echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg] https://dbeaver.io/debs/dbeaver-ce /" \
      | sudo tee /etc/apt/sources.list.d/dbeaver.list >/dev/null
    sudo tee /etc/apt/apt.conf.d/52dbeaver-unattended >/dev/null <<'EOF'
Unattended-Upgrade::Origins-Pattern {
    "site=dbeaver.io";
};
EOF
    sudo apt-get update
    sudo apt-get install -y dbeaver-ce
  fi
fi

# ------------------------------------------------------------------------------
# 4. scrcpy (espejo de pantalla Android auto-actualizado por snapd)
# ------------------------------------------------------------------------------
info "4/11 scrcpy"
if command -v scrcpy >/dev/null 2>&1; then
  present "scrcpy ($(command -v scrcpy))"
else
  missing "scrcpy (vía snap o apt)"
  if [ "$DRY_RUN" = false ]; then
    if command -v snap >/dev/null 2>&1; then
      sudo snap install scrcpy
    else
      sudo apt-get install -y scrcpy
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 5. Blindaje Triple Supply-Chain (24 horas: npm + pnpm + Bun)
# ------------------------------------------------------------------------------
info "5/11 Políticas de Seguridad Supply-Chain (ventana mínima de 24h)"
if [ "$DRY_RUN" = true ]; then
  [ -f "$HOME/.npmrc" ] && present "~/.npmrc" || missing "~/.npmrc"
  [ -f "$HOME/.config/pnpm/rc" ] && present "~/.config/pnpm/rc" || missing "~/.config/pnpm/rc"
  [ -f "$HOME/.bunfig.toml" ] && present "~/.bunfig.toml" || missing "~/.bunfig.toml"
else
  cp "$REPO_DIR/config/npmrc" "$HOME/.npmrc"
  sed "s|__HOME__|$HOME|g" "$REPO_DIR/config/pnpmrc.template" > "$HOME/.config/pnpm/rc"
  cp "$REPO_DIR/config/bunfig.toml" "$HOME/.bunfig.toml"
  present "Aplicados ~/.npmrc (1d), ~/.config/pnpm/rc (1440m + ignore-scripts) y ~/.bunfig.toml (86400s)"
fi

# ------------------------------------------------------------------------------
# 6. NVM + Node.js LTS + pnpm standalone + vercel y supabase globales
# ------------------------------------------------------------------------------
info "6/11 NVM, Node.js LTS, pnpm standalone, Vercel CLI y Supabase CLI"
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  present "NVM ($NVM_DIR)"
else
  missing "NVM (Node Version Manager)"
  if [ "$DRY_RUN" = false ]; then
    NVM_TAG="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name)"
    PROFILE=/dev/null bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_TAG}/install.sh | bash"
  fi
fi

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
  if command -v node >/dev/null 2>&1; then
    present "Node.js ($(node -v)) & npm ($(npm -v))"
  else
    missing "Node.js LTS (lts/*)"
    if [ "$DRY_RUN" = false ]; then
      nvm install 'lts/*'
      nvm alias default 'lts/*'
    fi
  fi
fi

if [ -x "$PNPM_HOME/bin/pnpm" ] || command -v pnpm >/dev/null 2>&1; then
  present "pnpm ($(pnpm -v))"
else
  missing "pnpm standalone"
  if [ "$DRY_RUN" = false ]; then
    curl -fsSL https://get.pnpm.io/install.sh | env ENV=/dev/null SHELL=/bin/sh PNPM_HOME="$PNPM_HOME" sh -
  fi
fi

if [ -x "$PNPM_HOME/bin/vercel" ] || command -v vercel >/dev/null 2>&1; then
  present "Vercel CLI ($(vercel --version 2>&1 | head -n1))"
else
  missing "Vercel CLI (pnpm global)"
  if [ "$DRY_RUN" = false ]; then
    "$PNPM_HOME/bin/pnpm" add -g vercel
  fi
fi

if [ -x "$PNPM_HOME/bin/supabase" ] || command -v supabase >/dev/null 2>&1; then
  present "Supabase CLI ($(supabase --version 2>&1 | head -n1))"
else
  missing "Supabase CLI (pnpm global)"
  if [ "$DRY_RUN" = false ]; then
    "$PNPM_HOME/bin/pnpm" add -g supabase
  fi
fi

# ------------------------------------------------------------------------------
# 7. Bun, Deno y Python (uv)
# ------------------------------------------------------------------------------
info "7/11 Bun, Deno y uv (Python)"
if [ -x "$BUN_INSTALL/bin/bun" ] || command -v bun >/dev/null 2>&1; then
  present "Bun ($(bun -v))"
else
  missing "Bun runtime"
  [ "$DRY_RUN" = false ] && curl -fsSL https://bun.sh/install | bash
fi

if [ -x "$DENO_INSTALL/bin/deno" ] || command -v deno >/dev/null 2>&1; then
  present "Deno ($(deno --version | head -n1))"
else
  missing "Deno runtime"
  [ "$DRY_RUN" = false ] && curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path
fi

if [ -x "$HOME/.local/bin/uv" ] || command -v uv >/dev/null 2>&1; then
  present "uv ($(uv --version))"
else
  missing "uv (gestor ultrarrápido de Python)"
  [ "$DRY_RUN" = false ] && curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
fi

# ------------------------------------------------------------------------------
# 8. Herramientas de Automatización + Android Studio + Android SDK + Flutter
# ------------------------------------------------------------------------------
info "8/11 Scripts del Stack, Android Studio, Android SDK y Flutter"
if [ "$DRY_RUN" = false ]; then
  install -m 755 "$REPO_DIR/bin/dev-check" "$HOME/.local/bin/dev-check"
  install -m 755 "$REPO_DIR/bin/dev-update" "$HOME/.local/bin/dev-update"
  install -m 755 "$REPO_DIR/bin/update-android-studio" "$HOME/.local/bin/update-android-studio"
fi

if [ -d "/opt/android-studio" ]; then
  present "Android Studio (/opt/android-studio)"
else
  missing "Android Studio Stable (/opt/android-studio)"
  [ "$DRY_RUN" = false ] && "$HOME/.local/bin/update-android-studio" --install
fi

if [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  present "Android SDK Command-line Tools ($ANDROID_HOME)"
else
  missing "Android SDK Command-line Tools + platform-tools + emulator"
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    CMD_URL="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml | grep -oE 'commandlinetools-linux-[0-9]+_latest\.zip' | head -n1)"
    TMP_SDK="$(mktemp -d)"
    curl -fL -o "$TMP_SDK/cmdline.zip" "https://dl.google.com/android/repository/${CMD_URL}"
    unzip -q "$TMP_SDK/cmdline.zip" -d "$TMP_SDK"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$TMP_SDK/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf "$TMP_SDK"
    SDK_JAVA="${JAVA_HOME:-/opt/android-studio/jbr}"
    yes | JAVA_HOME="$SDK_JAVA" "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
    JAVA_HOME="$SDK_JAVA" "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "emulator" "cmdline-tools;latest"
  fi
fi

if [ -x "$HOME/flutter/bin/flutter" ]; then
  present "Flutter ($("$HOME/flutter/bin/flutter" --version | head -n1))"
else
  missing "Flutter SDK (canal stable en $HOME/flutter)"
  if [ "$DRY_RUN" = false ]; then
    git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
    "$HOME/flutter/bin/flutter" precache
    yes | "$HOME/flutter/bin/flutter" doctor --android-licenses >/dev/null 2>&1 || true
  fi
fi

# ------------------------------------------------------------------------------
# 9. Agentes y CLIs de IA (agy, opencode, claude, codex)
# ------------------------------------------------------------------------------
info "9/11 Herramientas IA de Desarrollo (agy, opencode, claude, codex)"

install_ai_tool() {
  local label="$1" bin_name="$2" install_cmd="$3"
  if command -v "$bin_name" >/dev/null 2>&1; then
    present "$label ($(command -v "$bin_name"))"
  else
    missing "$label"
    [ "$DRY_RUN" = false ] && eval "$install_cmd"
  fi
}

install_ai_tool "Antigravity CLI (agy)" "agy"      "curl -fsSL https://antigravity.google/cli/install.sh | bash"
install_ai_tool "OpenCode"              "opencode" "curl -fsSL https://opencode.ai/install | bash"
install_ai_tool "Claude Code"           "claude"   "curl -fsSL https://claude.ai/install.sh | bash"
install_ai_tool "Codex CLI"             "codex"    "curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh"

# ------------------------------------------------------------------------------
# 10. Oh-My-Zsh y Perfiles de Shell (.zshrc / .bashrc)
# ------------------------------------------------------------------------------
info "10/11 Oh-My-Zsh y Configuración Deduplicada de Shell"
if [ -d "$HOME/.oh-my-zsh" ]; then
  present "Oh-My-Zsh ($HOME/.oh-my-zsh)"
else
  missing "Oh-My-Zsh"
  if [ "$DRY_RUN" = false ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
fi

if [ "$DRY_RUN" = false ]; then
  if [ -f "$HOME/.zshrc" ] && ! cmp -s "$REPO_DIR/config/zshrc" "$HOME/.zshrc"; then
    cp -a "$HOME/.zshrc" "$HOME/.zshrc.bak_$(date +%Y%m%d_%H%M%S)"
  fi
  cp "$REPO_DIR/config/zshrc" "$HOME/.zshrc"

  if [ -f "$HOME/.bashrc" ] && ! grep -q "# >>> stack-dev >>>" "$HOME/.bashrc" && ! grep -q "PNPM_HOME" "$HOME/.bashrc"; then
    cat "$REPO_DIR/config/bashrc.snippet" >> "$HOME/.bashrc"
  fi
  present "Perfiles ~/.zshrc y ~/.bashrc sincronizados"
else
  present "Plantillas listas en config/zshrc y config/bashrc.snippet"
fi

# ------------------------------------------------------------------------------
# 11. Temporizador Automático Diario (systemd --user)
# ------------------------------------------------------------------------------
info "11/11 Programación Diaria Automática (systemd --user)"
if [ "$DRY_RUN" = false ]; then
  cp "$REPO_DIR/config/systemd/dev-update.service" "$HOME/.config/systemd/user/dev-update.service"
  cp "$REPO_DIR/config/systemd/dev-update.timer" "$HOME/.config/systemd/user/dev-update.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now dev-update.timer
  present "Servicio diario dev-update.timer habilitado y activo"
  echo ""
  "$HOME/.local/bin/dev-check"
else
  systemctl --user is-active --quiet dev-update.timer 2>/dev/null \
    && present "dev-update.timer ya está activo" \
    || missing "Habilitar dev-update.timer en systemd --user"
  echo -e "\n${BOLD}${GREEN}✔ Simulación --dry-run completada sin modificar el sistema.${NC}"
fi

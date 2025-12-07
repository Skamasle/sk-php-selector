#!/bin/bash
# ==============================================================================
# Skamasle PHP SELECTOR for VestaCP (CentOS/RHEL 6/7)
# Extended & Hardened by Konstantinos Vlachos — version 1.8 (Stable + Force Reinstall)
#
# Features:
#   - Supports Remi SCL PHP 5.4 → 8.3
#   - Preserves system PHP (/usr/bin/php) – no upgrades, no replacements
#   - Installs only parallel SCL versions (phpXX-php) under /opt/remi/phpXX/
#   - Auto-installs Remi repo if missing
#   - Fetches Vesta templates from GitHub, fallback to local or placeholder
#   - Safe re-run (idempotent)
#   - Optional --with-fpm flag to install phpXX-php-fpm and enable service
#   - ✅ New: --force runs yum --reinstall, refreshes templates & restarts FPM
# ==============================================================================

set -euo pipefail

# --------------------------- Configuration -----------------------------------
LOGFILE="/var/log/skphp.log"
TEMPLATE_DIR="/usr/local/vesta/data/templates/web/httpd"
REMI_REPO_FILE="/etc/yum.repos.d/remi.repo"
SUPPORTED=(54 55 56 70 71 72 73 74 80 81 82 83)
FPM_FLAG=0
FORCE_FLAG=0
DRY_RUN="${DRY_RUN:-0}"

mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
# ------------------------------------------------------------------------------

# --------------------------- Color functions ----------------------------------
c_reset(){ tput sgr0 2>/dev/null || true; }
c_red(){   tput setaf 1 2>/dev/null || true; }
c_grn(){   tput setaf 2 2>/dev/null || true; }
c_yel(){   tput setaf 3 2>/dev/null || true; }
c_blu(){   tput setaf 4 2>/dev/null || true; }
say(){ echo -e "$*"; }
info(){ c_blu; say "$*"; c_reset; }
ok(){   c_grn; say "$*"; c_reset; }
warn(){ c_yel; say "$*"; c_reset; }
err(){  c_red; say "$*"; c_reset; }
# ------------------------------------------------------------------------------

# ---------------------------- Utility functions ------------------------------
die(){ err "ERROR: $*"; exit 1; }
log(){ printf '%s %s\n' "[$(date +'%F %T')]" "$*" >>"$LOGFILE"; }

detect_osver(){ grep -o "[0-9]" /etc/redhat-release | head -n1; }
to_fullver(){ echo "${1:0:1}.${1:1:1}"; }

php_current_short(){
  if command -v php >/dev/null 2>&1; then
    php -v 2>/dev/null | head -n1 | grep -Po '([578])\.\d+' || true
  else
    echo ""
  fi
}

have_pkg(){ rpm -qa | grep -q -- "$1"; }
verify_scl_php(){ [[ -x "/opt/remi/php$1/root/usr/bin/php" ]]; }
ensure_template_dir(){ mkdir -p "$TEMPLATE_DIR"; }

safe_link(){
  local t="$1" l="$2"
  [ -L "$l" ] && rm -f "$l"
  ln -s "$t" "$l"
}
# ------------------------------------------------------------------------------

# ----------------------------- Repo management --------------------------------
ensure_remi(){
  if [[ ! -f "$REMI_REPO_FILE" ]]; then
    info "Installing Remi repository..."
    local osver; osver="$(detect_osver)"
    case "$osver" in
      7) yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm >>"$LOGFILE" 2>&1 ;;
      6) yum install -y https://rpms.remirepo.net/enterprise/remi-release-6.rpm >>"$LOGFILE" 2>&1 ;;
      *) die "Unsupported OS version (need CentOS/RHEL 6 or 7)." ;;
    esac
  fi
  yum install -y yum-utils >>"$LOGFILE" 2>&1 || true
  # Enable base Remi collections (NOT remi-phpXX by default)
  yum-config-manager --enable remi remi-safe remi-modular >>"$LOGFILE" 2>&1 || true
}

enable_subrepo(){
  local v="$1" subrepo="remi-php${v}"
  if yum repolist all | grep -qE "^\s*${subrepo}\s"; then
    yum-config-manager --enable "${subrepo}" >>"$LOGFILE" 2>&1 || true
    info "Enabled subrepo: ${subrepo}"
  else
    warn "Repo ${subrepo} not found (skipping; assuming packages already present)"
  fi
}
# ------------------------------------------------------------------------------

# ---------------------------- Template fetching -------------------------------
fetch_template_script() {
  local v="$1"
  local remote_url="https://raw.githubusercontent.com/Skamasle/sk-php-selector/master/sk-php${v}-centos.sh"
  local dest="${TEMPLATE_DIR}/sk-php${v}.sh"
  local localfile="${PWD}/sk-php${v}-centos.sh"
  local altfile="/root/sk-php-selector/sk-php${v}-centos.sh"

  ensure_template_dir

  # 1️⃣ Try GitHub first
  if curl -fsSL "$remote_url" -o "$dest"; then
    chmod +x "$dest"
    info "Fetched remote template for PHP ${v} from GitHub."
    return 0
  fi

  # 2️⃣ Try local fallback (current directory)
  if [[ -f "$localfile" ]]; then
    info "Using local file: $localfile"
    cp -f "$localfile" "$dest"
    chmod +x "$dest"
    return 0
  fi

  # 3️⃣ Try alternate fallback (/root/sk-php-selector/)
  if [[ -f "$altfile" ]]; then
    info "Using alt local file: $altfile"
    cp -f "$altfile" "$dest"
    chmod +x "$dest"
    return 0
  fi

  # 4️⃣ No luck — create placeholder
  warn "No template found for PHP ${v}. Creating placeholder."
  cat > "$dest" <<EOF
#!/bin/bash
# Placeholder for PHP ${v}
# This file generated automatically (no remote or local version found)
EOF
  chmod +x "$dest"
}
# ------------------------------------------------------------------------------

# ------------------------------ Template setup --------------------------------
fixit(){
  local v="$1" full; full="$(to_fullver "$v")"
  info "Configuring Vesta templates for PHP ${full}..."
  fetch_template_script "$v"

  safe_link "${TEMPLATE_DIR}/phpfcgid.stpl" "${TEMPLATE_DIR}/sk-php${v}.stpl"
  safe_link "${TEMPLATE_DIR}/phpfcgid.tpl"  "${TEMPLATE_DIR}/sk-php${v}.tpl"

  if [ -e "/etc/opt/remi/php${v}/php.ini" ]; then
    safe_link "/etc/opt/remi/php${v}/php.ini" "/etc/php${v}.ini"
  fi
  if [ -d "/etc/opt/remi/php${v}/php.d" ]; then
    safe_link "/etc/opt/remi/php${v}/php.d" "/etc/php${v}.d"
  fi
  ok "Templates ready for PHP ${full}."
}
# ------------------------------------------------------------------------------

# ----------------------------- PHP Installation -------------------------------
install_php_version(){
  local v="$1" full; full="$(to_fullver "$v")"
  local base="php${v}-php"
  local active; active="$(php_current_short || true)"

  say "------------------------------------------------------------------------------"
  info "Installing SCL PHP ${full} (php${v}) — keeping system PHP intact"
  say "------------------------------------------------------------------------------"

  # ✅ Hard-protect base PHP from Remi (do not upgrade php/php-cli/etc)
  yum-config-manager --disable remi-php* >>"$LOGFILE" 2>&1 || true

  if [[ -n "$active" ]]; then
    info "Current system PHP is ${active} (will NOT be touched)."
  fi

  enable_subrepo "$v"

  if have_pkg "${base}-common" && [[ "$FORCE_FLAG" != "1" ]]; then
    ok "PHP ${full} already installed under /opt/remi/php${v}/"
  else

    if [[ "$FORCE_FLAG" == "1" ]]; then
      warn "FORCE mode: Reinstalling PHP ${full} packages"
      YUM_CMD="yum install --reinstall -y"
    else
      YUM_CMD="yum install -y"
    fi

    $YUM_CMD \
      php${v}-php \
      php${v}-php-cli php${v}-php-common php${v}-php-gd php${v}-php-mbstring \
      php${v}-php-mysqlnd php${v}-php-pdo php${v}-php-xml php${v}-php-zip \
      php${v}-php-opcache php${v}-php-xmlrpc php${v}-php-soap php${v}-php-pecl-apcu \
      ${FPM_FLAG:+php${v}-php-fpm} \
      --setopt=tsflags=nodocs \
      --disablerepo='remi-php*' \
      --enablerepo="remi,remi-safe,remi-modular,remi-php${v}" \
      --exclude='php,php-cli,php-common,php-fpm,php-mysqlnd,php-pdo,php-gd,php-xml,php-mbstring' \
      --skip-broken >>"$LOGFILE" 2>&1
  fi


  if verify_scl_php "$v"; then
    ok "Verified SCL binary: /opt/remi/php${v}/root/usr/bin/php"
    fixit "$v"

    if [[ "$FPM_FLAG" == "1" && "$FORCE_FLAG" == "1" ]]; then
      local svc="php${v}-php-fpm"
      if systemctl list-unit-files | grep -q "^${svc}\.service"; then
        systemctl restart "$svc" >>"$LOGFILE" 2>&1 || true
        ok "Restarted FPM service: ${svc}"
      fi
    fi
  else
    err "Binary missing for php${v}. Check $LOGFILE."
  fi
}
# ------------------------------------------------------------------------------

# ------------------------------- Install all ----------------------------------
install_all(){
  info "Installing all supported PHP versions..."
  for v in "${SUPPORTED[@]}"; do
    install_php_version "$v"
  done
}
# ------------------------------------------------------------------------------

# ------------------------------- Summary --------------------------------------
summarize(){
  say
  say "================== Installation Summary =================="
  printf "%-8s | %-8s | %-40s\n" "Version" "Status" "Binary"
  printf "%-8s-+-%-8s-+-%-40s\n" "--------" "--------" "----------------------------------------"
  for v in "${SUPPORTED[@]}"; do
    local full; full="$(to_fullver "$v")"
    local bin="/opt/remi/php${v}/root/usr/bin/php"
    if [[ -x "$bin" ]]; then
      c_grn; printf "%-8s | %-8s" "$full" "OK"; c_reset
      printf " | %-40s\n" "$bin"
    else
      c_red; printf "%-8s | %-8s" "$full" "MISSING"; c_reset
      printf " | %-40s\n" "-"
    fi
  done
  say "=========================================================="
  say "Logs: $LOGFILE"
}
# ------------------------------------------------------------------------------

# ------------------------------- Usage ----------------------------------------
usage(){
cat <<EOF

Usage:
  bash $0 all [--with-fpm] [--force]
  bash $0 php81 php83 [--with-fpm] [--force]

Options:
  --with-fpm    Install phpXX-php-fpm and enable the service.
  --force       Run yum --reinstall, refresh templates & restart FPM

Supported: 54 55 56 70 71 72 73 74 80 81 82 83

Notes:
  - System PHP (/usr/bin/php) is never upgraded or replaced by this script.
  - Extra PHP versions are installed as SCL under /opt/remi/phpXX/root/usr/bin/php.
EOF
}
# ------------------------------------------------------------------------------

# --------------------------------- Main ---------------------------------------
main(){
  [[ -f /etc/redhat-release ]] || die "Only CentOS/RHEL supported."
  local os; os="$(detect_osver)"
  [[ "$os" == "6" || "$os" == "7" ]] || die "Only CentOS/RHEL 6 or 7 supported."

  ensure_remi

  if [[ $# -lt 1 ]]; then usage; exit 2; fi

  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-fpm) FPM_FLAG=1; shift ;;
      --force) FORCE_FLAG=1; shift ;;
      all|php54|php55|php56|php70|php71|php72|php73|php74|php80|php81|php82|php83)
        args+=("$1"); shift ;;
      -h|--help) usage; exit 0 ;;
      *) warn "Unknown option: $1"; shift ;;
    esac
  done

  if [[ "${#args[@]}" -eq 0 ]]; then
    warn "No PHP versions specified."
    usage
    exit 2
  fi

  info "Detected OS:"; cat /etc/redhat-release
  info "Active system PHP: $(php_current_short || echo none)"
  info "FPM install: $([[ "$FPM_FLAG" == "1" ]] && echo enabled || echo disabled)"
  info "Force mode: $([[ "$FORCE_FLAG" == "1" ]] && echo enabled || echo disabled)"
  say "----------------------------------------------------------"

  for arg in "${args[@]}"; do
    case "$arg" in
      all) install_all ;;
      php54) install_php_version 54 ;;
      php55) install_php_version 55 ;;
      php56) install_php_version 56 ;;
      php70) install_php_version 70 ;;
      php71) install_php_version 71 ;;
      php72) install_php_version 72 ;;
      php73) install_php_version 73 ;;
      php74) install_php_version 74 ;;
      php80) install_php_version 80 ;;
      php81) install_php_version 81 ;;
      php82) install_php_version 82 ;;
      php83) install_php_version 83 ;;
    esac
  done

  summarize
  ok "Installation complete!"
}

main "$@"

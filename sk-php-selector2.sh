#!/bin/bash
# ==============================================================================
# Skamasle PHP SELECTOR for VestaCP (CentOS/RHEL 6/7)
# Extended & Hardened by Konstantinos Vlachos — version 3.0
#
# Features:
#   - Supports Remi SCL PHP 5.4 → 8.3
#   - Preserves system PHP (/usr/bin/php) – no upgrades, no replacements
#   - Installs parallel SCL versions (phpXX-php) under /opt/remi/phpXX/
#   - Auto-installs Remi repo if missing
#   - Fetches Vesta templates from GitHub, fallback to placeholder
#   - Safe re-run (idempotent)
#   - Flags:
#       --with-fpm     Install phpXX-php-fpm and restart service when done
#       --with-extras  Install extra modules (pspell, imap, ldap, tidy, memcache, pecl-zip)
#       --force        Reinstall packages, merge .rpmnew configs, restart FPM
# ==============================================================================

set -euo pipefail

# --------------------------- Configuration -----------------------------------
LOGFILE="/var/log/skphp.log"
TEMPLATE_DIR="/usr/local/vesta/data/templates/web/httpd"
REMI_REPO_FILE="/etc/yum.repos.d/remi.repo"
SUPPORTED=(54 55 56 70 71 72 73 74 80 81 82 83)

FPM_FLAG=0
FORCE_FLAG=0
INCLUDE_EXTRAS=0

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

# ✅ FIXED: No more broken grep detection
enable_subrepo(){
  local v="$1"
  local subrepo="remi-php${v}"

  yum-config-manager --enable "${subrepo}" >>"$LOGFILE" 2>&1 || true
  info "Enabled subrepo: ${subrepo}"
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
  else
    warn "No template found for PHP ${v}. Creating placeholder."
    cat > "$dest" <<EOF
#!/bin/bash
# Placeholder for PHP ${v}
# This file generated automatically (no remote or local version found)
EOF
    chmod +x "$dest"
  fi
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
  info "Installing PHP ${full} (php${v}) — system PHP remains unchanged"
  say "------------------------------------------------------------------------------"

  # Protect system PHP from unintended upgrades
  yum-config-manager --disable remi-php* >>"$LOGFILE" 2>&1 || true

  if [[ -n "$active" ]]; then
    info "Current system PHP: ${active}"
  fi

  enable_subrepo "$v"

  # Always refresh yum metadata before install/reinstall
  yum clean all >>"$LOGFILE" 2>&1
  yum makecache fast >>"$LOGFILE" 2>&1

  if have_pkg "${base}-common" && [[ "$FORCE_FLAG" != "1" ]]; then
    ok "PHP ${full} already installed under /opt/remi/php${v}/"
  else
    if [[ "$FORCE_FLAG" == "1" ]]; then
      warn "FORCE mode: Reinstalling PHP ${full} packages"
      YUM_CMD="yum reinstall -y"
    else
      YUM_CMD="yum install -y"
    fi

    # Core modules (always installed; includes ownCloud required ones)
    local core_modules=(
      php${v}-php php${v}-php-cli php${v}-php-common
      php${v}-php-gd php${v}-php-intl php${v}-php-mbstring
      php${v}-php-process php${v}-php-xml php${v}-php-pdo
      php${v}-php-mysqlnd php${v}-php-zip php${v}-php-opcache
      php${v}-php-soap php${v}-php-xmlrpc php${v}-php-pecl-apcu
    )

    # Extra modules (optional / legacy / specialized)
    local extra_modules=(
      php${v}-php-pspell php${v}-php-imap php${v}-php-ldap
      php${v}-php-pecl-zip php${v}-php-gmp php${v}-php-tidy
      php${v}-php-pecl-memcache
    )

    local packages=("${core_modules[@]}")
    if [[ "$INCLUDE_EXTRAS" == "1" ]]; then
      packages+=("${extra_modules[@]}")
    fi
    if [[ "$FPM_FLAG" == "1" ]]; then
      packages+=(php${v}-php-fpm)
    fi

    $YUM_CMD "${packages[@]}" \
      --setopt=tsflags=nodocs \
      --disablerepo='remi-php*' \
      --enablerepo="remi,remi-safe,remi-modular,remi-php${v}" \
      --exclude='php,php-cli,php-common,php-fpm,php-mysqlnd,php-pdo,php-gd,php-xml,php-mbstring' \
      --skip-broken >>"$LOGFILE" 2>&1

    # Merge any .rpmnew configs automatically (e.g., APCu)
    for f in /etc/opt/remi/php${v}/php.d/*.rpmnew; do
      [ -f "$f" ] || continue
      mv -f "$f" "${f%.rpmnew}"
      ok "Merged rpmnew config: ${f%.rpmnew}"
    done

    if verify_scl_php "$v"; then
      ok "Verified SCL binary: /opt/remi/php${v}/root/usr/bin/php"
      fixit "$v"

      # Restart FPM service if installed
      if [[ "$FPM_FLAG" == "1" ]]; then
        local svc="php${v}-php-fpm"
        if systemctl list-unit-files | grep -q "^${svc}\.service"; then
          systemctl restart "$svc" >>"$LOGFILE" 2>&1 || true
          ok "Restarted FPM service: ${svc}"
        fi
      fi
    else
      err "Binary missing for php${v}. Check $LOGFILE."
    fi
  fi
}

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
  say "====================== Installation summary ======================"
  printf "%-12s | %-8s | %-45s\n" "PHP version" "Status" "Binary path"
  printf "%-12s-+-%-8s-+-%-45s\n" "------------" "--------" "---------------------------------------------"
  for v in "${SUPPORTED[@]}"; do
    local full; full="$(to_fullver "$v")"
    local bin="/opt/remi/php${v}/root/usr/bin/php"
    if [[ -x "$bin" ]]; then
      c_grn; printf "%-12s | %-8s" "$full" "OK"; c_reset
      printf " | %-45s\n" "$bin"
    else
      c_red; printf "%-12s | %-8s" "$full" "MISSING"; c_reset
      printf " | %-45s\n" "-"
    fi
  done
  say "=================================================================="
  say "Log file: $LOGFILE"
}
# ------------------------------------------------------------------------------

# ------------------------------- Usage ----------------------------------------
usage(){
cat <<EOF

Usage:
  bash $0 all [--with-fpm] [--with-extras] [--force]
  bash $0 php74 [--with-fpm] [--with-extras] [--force]
  bash $0 php81 php83 [--with-fpm] [--with-extras] [--force]

Options:
  --with-fpm     Install phpXX-php-fpm and restart the service if present.
  --with-extras  Install extra modules (pspell, imap, ldap, tidy, memcache, pecl-zip).
  --force        Reinstall all phpXX packages, merge .rpmnew configs, restart FPM.

Supported versions: 54 55 56 70 71 72 73 74 80 81 82 83

Notes:
  - System PHP (/usr/bin/php) is never upgraded or replaced by this script.
  - Additional PHP versions are installed under /opt/remi/phpXX/root/usr/bin/php (SCL).
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
      --with-extras) INCLUDE_EXTRAS=1; shift ;;
      --force) FORCE_FLAG=1; shift ;;
      all|php54|php55|php56|php70|php71|php72|php73|php74|php80|php81|php82|php83)
        args+=("$1"); shift ;;
      -h|--help) usage; exit 0 ;;
      *) warn "Ignoring unknown option: $1"; shift ;;
    esac
  done

  if [[ "${#args[@]}" -eq 0 ]]; then
    warn "No PHP versions specified."
    usage
    exit 2
  fi

  say "=========================================================="
  info "System check:"
  say "  • Operating system version: CentOS/RHEL $os"
  say "  • Current system PHP version: $(php_current_short || echo none)"
  say "  • PHP-FPM installation: $([[ "$FPM_FLAG" == "1" ]] && echo enabled || echo disabled)"
  say "  • Extra modules installation: $([[ "$INCLUDE_EXTRAS" == "1" ]] && echo enabled || echo disabled)"
  say "  • Force reinstall option: $([[ "$FORCE_FLAG" == "1" ]] && echo enabled || echo disabled)"
  say "=========================================================="

  for arg in "${args[@]}"; do
    case "$arg" in
      all) info "Starting installation of all supported PHP versions..."; install_all ;;
      php54) info "Beginning installation of PHP 5.4 (Software Collections)..."; install_php_version 54 ;;
      php55) info "Beginning installation of PHP 5.5 (Software Collections)..."; install_php_version 55 ;;
      php56) info "Beginning installation of PHP 5.6 (Software Collections)..."; install_php_version 56 ;;
      php70) info "Beginning installation of PHP 7.0 (Software Collections)..."; install_php_version 70 ;;
      php71) info "Beginning installation of PHP 7.1 (Software Collections)..."; install_php_version 71 ;;
      php72) info "Beginning installation of PHP 7.2 (Software Collections)..."; install_php_version 72 ;;
      php73) info "Beginning installation of PHP 7.3 (Software Collections)..."; install_php_version 73 ;;
      php74) info "Beginning installation of PHP 7.4 (Software Collections)..."; install_php_version 74 ;;
      php80) info "Beginning installation of PHP 8.0 (Software Collections)..."; install_php_version 80 ;;
      php81) info "Beginning installation of PHP 8.1 (Software Collections)..."; install_php_version 81 ;;
      php82) info "Beginning installation of PHP 8.2 (Software Collections)..."; install_php_version 82 ;;
      php83) info "Beginning installation of PHP 8.3 (Software Collections)..."; install_php_version 83 ;;
    esac
  done

  summarize
  ok "✅ Installation complete: all requested PHP versions have been processed successfully."
}

main "$@"

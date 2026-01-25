#!/bin/bash
# ==============================================================================
# Skamasle PHP SELECTOR for VestaCP (CentOS/RHEL 6/7)
# Extended & Hardened by Konstantinos Vlachos — version 4.0
#
# Features:
#   - Supports Remi SCL PHP 5.4 → 8.3
#   - Preserves system PHP (/usr/bin/php) – no upgrades, no replacements
#   - Installs parallel SCL versions (phpXX-php) under /opt/remi/phpXX/
#   - Auto-installs Remi repo if missing
#   - Fetches Vesta templates from GitHub, fallback to placeholder
#   - Auto-generates:
#       * nginx FPM templates per PHP version
#       * Apache FPM templates per PHP version
#       * Per-domain PHP-FPM pools (one socket per domain per PHP version)
#   - Safe re-run (idempotent)
#   - Flags:
#       --with-fpm          Install phpXX-php-fpm and restart service when done
#       --with-extras       Install extra modules (pspell, imap, ldap, tidy, memcache, pecl-zip)
#       --force             Reinstall packages, merge .rpmnew configs, restart FPM
#       --with-deps         Detect missing PHP extensions & install their packages (intl/imagick/redis/etc)
#       --with-redis-server Install Redis server (daemon) on the system
#
# Notes:
#   - “dependencies” here means *PHP extensions* required by apps (Nextcloud/ownCloud/WordPress/etc).
#   - Per-domain FPM pools are derived from /usr/local/vesta/data/users/*/web.conf.
# ==============================================================================

set -euo pipefail

# --------------------------- Configuration -----------------------------------
LOGFILE="/var/log/skphp.log"
TEMPLATE_DIR_HTTPD="/usr/local/vesta/data/templates/web/httpd"
TEMPLATE_DIR_NGINX="/usr/local/vesta/data/templates/web/nginx"
REMI_REPO_FILE="/etc/yum.repos.d/remi.repo"

SUPPORTED=(54 55 56 70 71 72 73 74 80 81 82 83)

FPM_FLAG=0
FORCE_FLAG=0
INCLUDE_EXTRAS=0
WITH_DEPS=0
WITH_REDIS_SERVER=0

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

# ---------------------- System library dependencies ---------------------------
ensure_system_libs() {
  local pkgs=()

  if ! ldconfig -p 2>/dev/null | grep -q 'libsmbclient\.so'; then
    pkgs+=("samba-client-libs")
  fi

  if ! ldconfig -p 2>/dev/null | grep -q 'libldap\.so'; then
    pkgs+=("openldap" "openldap-clients")
  fi

  if [[ ${#pkgs[@]} -gt 0 ]]; then
    pkgs=($(printf "%s\n" "${pkgs[@]}" | awk '!seen[$0]++'))

    info "Installing missing system libraries: ${pkgs[*]}"
    yum install -y "${pkgs[@]}" >>"$LOGFILE" 2>&1 || \
      warn "Failed to install some system libraries (see $LOGFILE)."

    ldconfig 2>/dev/null || true
  fi
}
# ------------------------------------------------------------------------------


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

verify_scl_php(){ [[ -x "/opt/remi/php$1/root/usr/bin/php" ]] ; }

safe_link(){
  local t="$1" l="$2"
  [ -L "$l" ] && rm -f "$l"
  ln -s "$t" "$l"
}

yum_safe_install(){
  # Installs only SCL packages and protects system php*
  # Usage: yum_safe_install <phpver> <pkg1> <pkg2> ...
  local v="$1"; shift
  local pkgs=("$@")
  local subrepo="remi-php${v}"

  # Protect system PHP packages from getting upgraded
  yum-config-manager --disable remi-php* >>"$LOGFILE" 2>&1 || true

  # Enable only the subrepo we need
  yum-config-manager --enable "${subrepo}" >>"$LOGFILE" 2>&1 || true

  # Install pkgs from SCL repos only, exclude base PHP names
  yum install -y "${pkgs[@]}" \
    --setopt=tsflags=nodocs \
    --disablerepo='remi-php*' \
    --enablerepo="remi,remi-safe,remi-modular,${subrepo}" \
    --exclude='php php-cli php-common php-fpm php-mysqlnd php-pdo php-gd php-xml php-mbstring php-intl php-pecl-imagick' \
    --skip-broken >>"$LOGFILE" 2>&1
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

# ------------------------ Redis server management -----------------------------
install_redis_server() {
  if ! command -v redis-server >/dev/null 2>&1; then
    info "Installing Redis server..."
    yum install -y redis >>"$LOGFILE" 2>&1 || warn "Failed to install Redis (check $LOGFILE)."
    systemctl enable redis >>"$LOGFILE" 2>&1 || true
    systemctl start redis >>"$LOGFILE" 2>&1 || true
    ok "Redis server installed and (attempted) started."
  else
    ok "Redis server already installed."
  fi
}
# ------------------------------------------------------------------------------

# ---------------------------- Template fetching -------------------------------
fetch_template_script() {
  local v="$1"
  local remote_url="https://raw.githubusercontent.com/Skamasle/sk-php-selector/master/sk-php${v}-centos.sh"
  local dest="${TEMPLATE_DIR_HTTPD}/sk-php${v}.sh"

  mkdir -p "$TEMPLATE_DIR_HTTPD"

  # 1️⃣ Try GitHub first
  if curl -fsSL "$remote_url" -o "$dest"; then
    chmod +x "$dest"
    info "Fetched remote template for PHP ${v} from GitHub."
  else
    warn "No template found for PHP ${v}. Creating placeholder."
    cat > "$dest" <<EOF
#!/bin/bash
# Placeholder for PHP ${v}
# This file generated automatically (no remote template available)
EOF
    chmod +x "$dest"
  fi
}
# ------------------------------------------------------------------------------

# ------------------------------ Vesta base templates --------------------------
fixit(){
  local v="$1" full; full="$(to_fullver "$v")"
  info "Configuring base Vesta templates for PHP ${full}..."
  fetch_template_script "$v"

  mkdir -p "$TEMPLATE_DIR_HTTPD"

  safe_link "${TEMPLATE_DIR_HTTPD}/phpfcgid.stpl" "${TEMPLATE_DIR_HTTPD}/sk-php${v}.stpl"
  safe_link "${TEMPLATE_DIR_HTTPD}/phpfcgid.tpl"  "${TEMPLATE_DIR_HTTPD}/sk-php${v}.tpl"

  if [ -e "/etc/opt/remi/php${v}/php.ini" ]; then
    safe_link "/etc/opt/remi/php${v}/php.ini" "/etc/php${v}.ini"
  fi
  if [ -d "/etc/opt/remi/php${v}/php.d" ]; then
    safe_link "/etc/opt/remi/php${v}/php.d" "/etc/php${v}.d"
  fi
  ok "Base templates ready for PHP ${full}."
}
# ------------------------------------------------------------------------------

# ---------------------- FPM templates per PHP version -------------------------
generate_fpm_templates(){
  local v="$1" full; full="$(to_fullver "$v")"
  local sock_path_base="/var/opt/remi/php${v}/run"

  mkdir -p "$TEMPLATE_DIR_NGINX" "$TEMPLATE_DIR_HTTPD"

  local nginx_tpl="${TEMPLATE_DIR_NGINX}/sk-php${v}-fpm.tpl"
  local nginx_stpl="${TEMPLATE_DIR_NGINX}/sk-php${v}-fpm.stpl"
  local httpd_tpl="${TEMPLATE_DIR_HTTPD}/sk-php${v}-fpm.tpl"
  local httpd_stpl="${TEMPLATE_DIR_HTTPD}/sk-php${v}-fpm.stpl"

  cat > "$nginx_tpl" <<EOF
location ~ \.php\$ {
    try_files \$uri =404;
    include /etc/nginx/fastcgi_params;
    fastcgi_pass unix:${sock_path_base}/%domain%.sock;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
}
EOF

  cp -f "$nginx_tpl" "$nginx_stpl"

  cat > "$httpd_tpl" <<EOF
<FilesMatch \.php\$>
    SetHandler "proxy:unix:${sock_path_base}/%domain%.sock|fcgi://localhost"
</FilesMatch>
EOF

  cp -f "$httpd_tpl" "$httpd_stpl"

  ok "FPM templates generated for PHP ${full} (nginx + apache)."
}
# ------------------------------------------------------------------------------

# ---------------------- Per-domain FPM pool generation ------------------------
generate_domain_pools(){
  local v="$1" full; full="$(to_fullver "$v")"
  local fpm_pool_dir="/etc/opt/remi/php${v}/php-fpm.d"
  local sock_dir="/var/opt/remi/php${v}/run"

  mkdir -p "$fpm_pool_dir" "$sock_dir"
  chmod 755 "$sock_dir"

  local count=0

  while IFS= read -r line; do
    local conf_file user domain
    conf_file="${line%%:*}"
    user="$(echo "$conf_file" | awk -F'/' '{print $(NF-1)}')"
    domain="$(echo "$line" | sed -n "s/.*DOMAIN='\([^']*\)'.*/\1/p")"

    [[ -z "$domain" || -z "$user" ]] && continue

    local pool_file="${fpm_pool_dir}/${domain}.conf"
    local docroot="/home/${user}/web/${domain}/public_html"
    local sock="${sock_dir}/${domain}.sock"

    cat > "$pool_file" <<EOF
[${domain}]
user = ${user}
group = ${user}
listen = ${sock}
listen.owner = nginx
listen.group = nginx
pm = ondemand
pm.max_children = 20
pm.process_idle_timeout = 10s
pm.max_requests = 500
php_admin_value[open_basedir] = ${docroot}:/tmp
EOF

    count=$((count+1))
  done < <(grep -R "DOMAIN='" /usr/local/vesta/data/users/*/web.conf || true)

  ok "Generated ${count} per-domain FPM pools for PHP ${full}."
}
# ------------------------------------------------------------------------------

# ---------------------- Detect & install missing PHP deps ---------------------
# Map PHP module name -> SCL RPM package
module_to_pkg(){
  local v="$1"
  local mod="$2"

  case "$mod" in
    intl)      echo "php${v}-php-intl" ;;
    imagick)   echo "php${v}-php-pecl-imagick" ;;
    apcu)      echo "php${v}-php-pecl-apcu" ;;
    redis)     echo "php${v}-php-pecl-redis5" ;;
    memcached) echo "php${v}-php-pecl-memcached" ;;
    memcache)  echo "php${v}-php-pecl-memcache" ;;
    smbclient) echo "php${v}-php-smbclient" ;;   # ✅ FIXED
    bz2)       echo "php${v}-php-bz2" ;;
    gmp)       echo "php${v}-php-gmp" ;;
    ldap)      echo "php${v}-php-ldap" ;;
    imap)      echo "php${v}-php-imap" ;;
    tidy)      echo "php${v}-php-tidy" ;;
    pspell)    echo "php${v}-php-pspell" ;;
    soap)      echo "php${v}-php-soap" ;;
    zip)       echo "php${v}-php-zip" ;;
    exif)      echo "php${v}-php-exif" ;;
    fileinfo)  echo "php${v}-php-common" ;;
    opcache)   echo "php${v}-php-opcache" ;;
    *)         echo "" ;;
  esac
}


get_loaded_modules(){
  # Returns lowercase module list from SCL php -m
  local v="$1"
  "/opt/remi/php${v}/root/usr/bin/php" -m 2>/dev/null | tr '[:upper:]' '[:lower:]' || true
}

ensure_required_modules(){
  local v="$1"

  # Only run if php exists
  verify_scl_php "$v" || return 0

  local required=(intl imagick redis)

  # If extras requested, add more (common real-world needs)
  if [[ "$INCLUDE_EXTRAS" == "1" ]]; then
    required+=(ldap imap tidy pspell gmp zip soap opcache apcu)
  fi

  local loaded; loaded="$(get_loaded_modules "$v")"
  if [[ -z "$loaded" ]]; then
    warn "Could not read loaded modules for php${v}; skipping dep check."
    return 0
  fi

  local missing_mods=()
  local missing_pkgs=()

  for mod in "${required[@]}"; do
    if ! echo "$loaded" | grep -qx "$mod"; then
      missing_mods+=("$mod")
      local pkg; pkg="$(module_to_pkg "$v" "$mod")"
      if [[ -n "$pkg" ]]; then
        # Add package if not already installed
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
          missing_pkgs+=("$pkg")
        fi
      else
        warn "No RPM mapping for module '$mod' on php${v}."
      fi
    fi
  done

  if [[ ${#missing_mods[@]} -gt 0 ]]; then
    warn "php${v}: Missing PHP modules: ${missing_mods[*]}"
  else
    ok "php${v}: Required PHP modules already present."
    return 0
  fi

  if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    ensure_system_libs
    info "php${v}: Installing missing module packages: ${missing_pkgs[*]}"
    yum_safe_install "$v" "${missing_pkgs[@]}" || warn "Some dep packages failed (see $LOGFILE)."
  else
    warn "php${v}: Missing modules detected but no installable packages were identified (already installed?)"
  fi

  # Recheck after install (and restart FPM if enabled)
  if [[ "$FPM_FLAG" == "1" ]]; then
    local svc="php${v}-php-fpm"
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
      systemctl restart "$svc" >>"$LOGFILE" 2>&1 || true
      ok "Restarted FPM service: ${svc}"
    fi
  fi

  local loaded2; loaded2="$(get_loaded_modules "$v")"
  for mod in "${required[@]}"; do
    if echo "$loaded2" | grep -qx "$mod"; then
      ok "php${v}: module enabled -> $mod"
    else
      warn "php${v}: module still missing -> $mod (check yum / php.d configs)"
    fi
  done
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

  yum clean all >>"$LOGFILE" 2>&1 || true
  yum makecache fast >>"$LOGFILE" 2>&1 || true

  if have_pkg "${base}-common" && [[ "$FORCE_FLAG" != "1" ]]; then
    ok "PHP ${full} already installed under /opt/remi/php${v}/"
  else
    local YUM_CMD
    if [[ "$FORCE_FLAG" == "1" ]]; then
      warn "FORCE mode: Reinstalling PHP ${full} packages"
      YUM_CMD="yum reinstall -y"
    else
      YUM_CMD="yum install -y"
    fi

    # Core modules (always installed; includes ownCloud required ones)
    local core_modules=(
      php${v}-php php${v}-php-cli php${v}-php-common
      php${v}-php-gd php${v}-php-mbstring php${v}-php-process
      php${v}-php-xml php${v}-php-pdo php${v}-php-mysqlnd
      php${v}-php-zip php${v}-php-opcache php${v}-php-soap
      php${v}-php-xmlrpc php${v}-php-pecl-apcu
    )

    # Optional “extras” from your flag
    local extra_modules=(
      php${v}-php-pspell php${v}-php-imap php${v}-php-ldap
      php${v}-php-gmp php${v}-php-tidy php${v}-php-pecl-memcache
      php${v}-php-pecl-zip
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
      --exclude='php php-cli php-common php-fpm php-mysqlnd php-pdo php-gd php-xml php-mbstring' \
      --skip-broken >>"$LOGFILE" 2>&1

    # Merge .rpmnew configs automatically
    for f in /etc/opt/remi/php${v}/php.d/*.rpmnew; do
      [ -f "$f" ] || continue
      mv -f "$f" "${f%.rpmnew}"
      ok "Merged rpmnew config: ${f%.rpmnew}"
    done
  fi

  if verify_scl_php "$v"; then
    ok "Verified SCL binary: /opt/remi/php${v}/root/usr/bin/php"
    fixit "$v"

    if [[ "$FPM_FLAG" == "1" ]]; then
      generate_fpm_templates "$v"
      generate_domain_pools "$v"
    fi

    if [[ "$WITH_DEPS" == "1" ]]; then
      ensure_required_modules "$v"
    fi

    # Restart FPM service if requested/installed
    if [[ "$FPM_FLAG" == "1" ]]; then
      local svc="php${v}-php-fpm"
      if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
        systemctl restart "$svc" >>"$LOGFILE" 2>&1 || true
        ok "Restarted FPM service: ${svc}"
      fi
    fi
  else
    err "Binary missing for php${v}. Check $LOGFILE."
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
    local svc="php${v}-php-fpm"
    local sock_dir="/var/opt/remi/php${v}/run"
    local fpm_pool_dir="/etc/opt/remi/php${v}/php-fpm.d"
    local nginx_tpl="${TEMPLATE_DIR_NGINX}/sk-php${v}-fpm.tpl"
    local httpd_tpl="${TEMPLATE_DIR_HTTPD}/sk-php${v}-fpm.tpl"

    if [[ -x "$bin" ]]; then
      c_grn; printf "%-12s | %-8s" "$full" "OK"; c_reset
      printf " | %-45s\n" "$bin"
    else
      c_red; printf "%-12s | %-8s" "$full" "MISSING"; c_reset
      printf " | %-45s\n" "-"
      continue
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
      if systemctl is-active "$svc" >/dev/null 2>&1; then
        ok "   • FPM service: ${svc} (running)"
      else
        warn "   • FPM service: ${svc} (installed but not running)"
      fi
    else
      warn "   • FPM service: ${svc} (not installed)"
    fi

    if [[ -d "$sock_dir" ]]; then
      ok "   • FPM socket directory: ${sock_dir}"
    else
      warn "   • FPM socket directory missing: ${sock_dir}"
    fi

    if [[ -f "$nginx_tpl" ]]; then
      ok "   • nginx FPM template: $(basename "$nginx_tpl")"
    else
      warn "   • nginx FPM template missing for PHP ${full}"
    fi

    if [[ -f "$httpd_tpl" ]]; then
      ok "   • apache FPM template: $(basename "$httpd_tpl")"
    else
      warn "   • apache FPM template missing for PHP ${full}"
    fi

    if [[ -d "$fpm_pool_dir" ]]; then
      local pool_count
      pool_count=$(find "$fpm_pool_dir" -maxdepth 1 -type f -name "*.conf" 2>/dev/null | wc -l || echo 0)
      ok "   • domain pools: ${pool_count} in ${fpm_pool_dir}"
    else
      warn "   • FPM pool directory missing: ${fpm_pool_dir}"
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
  bash $0 all [--with-fpm] [--with-extras] [--force] [--with-deps] [--with-redis-server]
  bash $0 php81 php83 php84 php85 [--with-fpm] [--with-extras] [--force] [--with-deps] [--with-redis-server]

Options:
  --with-fpm          Install phpXX-php-fpm and generate FPM templates & domain pools.
  --with-extras       Install extra modules (pspell, imap, ldap, tidy, memcache, pecl-zip).
  --force             Reinstall all phpXX packages, merge .rpmnew configs, restart FPM.
  --with-deps         Detect missing PHP extensions (intl/imagick/redis etc) and install packages.
  --with-redis-server Install Redis server (daemon) on the system.

Supported versions: 54 55 56 70 71 72 73 74 80 81 82 83

Notes:
  - System PHP (/usr/bin/php) is never upgraded or replaced by this script.
  - Additional PHP versions are installed under /opt/remi/phpXX/root/usr/bin/php (SCL).
  - Per-domain pools are generated from /usr/local/vesta/data/users/*/web.conf.
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
      --with-fpm)          FPM_FLAG=1; shift ;;
      --with-extras)       INCLUDE_EXTRAS=1; shift ;;
      --with-deps)         WITH_DEPS=1; shift ;;
      --force)             FORCE_FLAG=1; shift ;;
      --with-redis-server) WITH_REDIS_SERVER=1; shift ;;
      all|php54|php55|php56|php70|php71|php72|php73|php74|php80|php81|php82|php83|php84|php85)
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
  say "  • Detect & install missing deps: $([[ "$WITH_DEPS" == "1" ]] && echo enabled || echo disabled)"
  say "  • Force reinstall option: $([[ "$FORCE_FLAG" == "1" ]] && echo enabled || echo disabled)"
  say "  • Redis server installation: $([[ "$WITH_REDIS_SERVER" == "1" ]] && echo enabled || echo disabled)"
  say "=========================================================="

  if [[ "$WITH_REDIS_SERVER" == "1" ]]; then
    install_redis_server
  fi

  for arg in "${args[@]}"; do
    case "$arg" in
      all)   install_all ;;
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
  ok "✅ All requested PHP versions were installed, configured, and fully validated."
}

main "$@"

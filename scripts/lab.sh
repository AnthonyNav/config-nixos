# shellcheck shell=bash

usage() {
  cat <<'USAGE'
Usage:
  lab doctor
  lab image almalinux
  lab create almalinux
  lab start almalinux
  lab stop almalinux
  lab status almalinux
  lab ssh almalinux [-- COMMAND...]
  lab console almalinux
  lab open almalinux
  lab snapshot almalinux NAME
  lab snapshots almalinux
  lab revert almalinux NAME
  lab reset almalinux [--force]
  lab delete almalinux [--force]
  lab purge-image almalinux [--force]

Runtime VM state, images, SSH keys, and snapshots stay local to each host.
USAGE
}

fail() {
  printf 'lab: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'lab: %s\n' "$*"
}

vsh() {
  virsh --connect "$LAB_URI" "$@"
}

require_profile() {
  case "${1:-}" in
    almalinux | alma | alma9 | almalinux9) ;;
    "") fail "missing profile; expected 'almalinux'" ;;
    *) fail "unknown profile '$1'; only 'almalinux' is currently declared" ;;
  esac
}

require_kvm() {
  [ -e /dev/kvm ] || fail "/dev/kvm is unavailable; enable hardware virtualization in firmware"
}

require_libvirt() {
  vsh uri >/dev/null 2>&1 || fail "cannot connect to $LAB_URI; deploy the virtualization lab and re-login so libvirtd group membership applies"
}

domain_exists() {
  vsh dominfo "$LAB_DOMAIN" >/dev/null 2>&1
}

pool_exists() {
  vsh pool-info "$LAB_POOL_NAME" >/dev/null 2>&1
}

network_exists() {
  vsh net-info "$LAB_NETWORK_NAME" >/dev/null 2>&1
}

volume_exists() {
  vsh vol-info --pool "$LAB_POOL_NAME" "$1" >/dev/null 2>&1
}

ensure_pool() {
  if ! pool_exists; then
    info "defining storage pool '$LAB_POOL_NAME'"
    vsh pool-define-as "$LAB_POOL_NAME" dir --target "$LAB_POOL_PATH" >/dev/null
    vsh pool-build "$LAB_POOL_NAME" >/dev/null
  fi

  if ! vsh pool-info "$LAB_POOL_NAME" | grep -Eq '^State:[[:space:]]+running$'; then
    vsh pool-start "$LAB_POOL_NAME" >/dev/null
  fi
  vsh pool-autostart "$LAB_POOL_NAME" >/dev/null
}

ensure_network() {
  if ! network_exists; then
    local network_xml
    network_xml="$(mktemp)"
    cat >"$network_xml" <<EOF_NETWORK
<network>
  <name>${LAB_NETWORK_NAME}</name>
  <forward mode='nat'/>
  <bridge name='${LAB_NETWORK_BRIDGE}' stp='on' delay='0'/>
  <ip address='${LAB_NETWORK_GATEWAY}' netmask='${LAB_NETWORK_NETMASK}'>
    <dhcp>
      <range start='${LAB_NETWORK_DHCP_START}' end='${LAB_NETWORK_DHCP_END}'/>
      <host mac='${LAB_GUEST_MAC}' name='${LAB_DOMAIN}' ip='${LAB_GUEST_IP}'/>
    </dhcp>
  </ip>
</network>
EOF_NETWORK

    info "defining isolated NAT network '$LAB_NETWORK_NAME'"
    if ! vsh net-define "$network_xml" >/dev/null; then
      rm -f "$network_xml"
      fail "failed to define '$LAB_NETWORK_NAME'"
    fi
    rm -f "$network_xml"
  fi

  if ! vsh net-info "$LAB_NETWORK_NAME" | grep -Eq '^Active:[[:space:]]+yes$'; then
    vsh net-start "$LAB_NETWORK_NAME" >/dev/null
  fi
  vsh net-autostart "$LAB_NETWORK_NAME" >/dev/null
}

cache_dir() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/virtualization-lab/images"
}

state_dir() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/virtualization-lab"
}

key_path() {
  printf '%s\n' "$(state_dir)/keys/almalinux_ed25519"
}

known_hosts_path() {
  printf '%s\n' "$(state_dir)/known_hosts"
}

forget_guest_host_key() {
  local known_hosts
  known_hosts="$(known_hosts_path)"
  if [ -f "$known_hosts" ]; then
    ssh-keygen -R "$LAB_GUEST_IP" -f "$known_hosts" >/dev/null 2>&1 || true
  fi
}

ensure_key() {
  local key
  key="$(key_path)"
  if [ ! -f "$key" ]; then
    mkdir -p "$(dirname "$key")"
    info "generating dedicated lab SSH key at $key"
    ssh-keygen -q -t ed25519 -N '' -C 'virtualization-lab' -f "$key"
  fi
  [ -f "${key}.pub" ] || fail "missing public key ${key}.pub"
}

verify_image_file() {
  local file="$1" actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [ "$actual" = "$LAB_IMAGE_SHA256" ] || fail "checksum mismatch for $file (expected $LAB_IMAGE_SHA256, got $actual)"
}

ensure_cached_image() {
  local dir file tmp actual
  dir="$(cache_dir)"
  file="$dir/$LAB_IMAGE_FILENAME"
  mkdir -p "$dir"

  if [ -f "$file" ]; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [ "$actual" = "$LAB_IMAGE_SHA256" ]; then
      printf '%s\n' "$file"
      return 0
    fi
    info "removing cached image with an invalid checksum" >&2
    rm -f "$file"
  fi

  tmp="${file}.partial"
  rm -f "$tmp"
  info "downloading pinned AlmaLinux ${LAB_IMAGE_VERSION} image (${LAB_IMAGE_BUILD})" >&2
  curl \
    --fail \
    --location \
    --proto '=https' \
    --tlsv1.2 \
    --retry 3 \
    --retry-delay 2 \
    --output "$tmp" \
    "$LAB_IMAGE_URL"
  verify_image_file "$tmp"
  mv "$tmp" "$file"
  printf '%s\n' "$file"
}

ensure_base_volume() {
  local cached virtual_size
  ensure_pool
  if volume_exists "$LAB_BASE_VOLUME"; then
    return 0
  fi

  cached="$(ensure_cached_image)"
  virtual_size="$(qemu-img info --output=json "$cached" | jq -er '."virtual-size"')"
  info "importing verified AlmaLinux base into '$LAB_POOL_NAME'"
  vsh vol-create-as "$LAB_POOL_NAME" "$LAB_BASE_VOLUME" "${virtual_size}B" --format qcow2 >/dev/null
  if ! vsh vol-upload "$LAB_BASE_VOLUME" "$cached" --pool "$LAB_POOL_NAME"; then
    vsh vol-delete "$LAB_BASE_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null 2>&1 || true
    fail "failed to import AlmaLinux base volume"
  fi
  vsh pool-refresh "$LAB_POOL_NAME" >/dev/null
  rm -f "$cached"
}

create_seed_volume() {
  local temp_dir user_data meta_data seed public_key seed_size
  temp_dir="$(mktemp -d)"
  user_data="$temp_dir/user-data"
  meta_data="$temp_dir/meta-data"
  seed="$temp_dir/seed.iso"
  public_key="$(cat "$(key_path).pub")"

  cat >"$user_data" <<EOF_USERDATA
#cloud-config
hostname: ${LAB_DOMAIN}
manage_etc_hosts: true
disable_root: true
ssh_pwauth: false
package_update: false
users:
  - name: ${LAB_GUEST_USER}
    gecos: University lab user
    groups: [wheel]
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${public_key}
EOF_USERDATA

  cat >"$meta_data" <<EOF_METADATA
instance-id: ${LAB_DOMAIN}-${LAB_IMAGE_BUILD}
local-hostname: ${LAB_DOMAIN}
EOF_METADATA

  cloud-localds "$seed" "$user_data" "$meta_data"
  seed_size="$(stat -c '%s' "$seed")"
  vsh vol-create-as "$LAB_POOL_NAME" "$LAB_SEED_VOLUME" "${seed_size}B" --format raw >/dev/null
  if ! vsh vol-upload "$LAB_SEED_VOLUME" "$seed" --pool "$LAB_POOL_NAME"; then
    rm -rf "$temp_dir"
    vsh vol-delete "$LAB_SEED_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null 2>&1 || true
    fail "failed to create cloud-init seed volume"
  fi
  rm -rf "$temp_dir"
}

create_guest_volume() {
  local base_path
  base_path="$(vsh vol-path --pool "$LAB_POOL_NAME" "$LAB_BASE_VOLUME")"
  vsh vol-create-as \
    "$LAB_POOL_NAME" \
    "$LAB_GUEST_VOLUME" \
    "${LAB_DISK_GIB}G" \
    --format qcow2 \
    --backing-vol "$base_path" \
    --backing-vol-format qcow2 >/dev/null
}

create_domain() {
  virt-install \
    --connect "$LAB_URI" \
    --name "$LAB_DOMAIN" \
    --memory "$LAB_MEMORY_MIB" \
    --vcpus "$LAB_VCPUS" \
    --cpu host \
    --import \
    --disk "vol=${LAB_POOL_NAME}/${LAB_GUEST_VOLUME},bus=virtio,cache=none,discard=unmap" \
    --disk "vol=${LAB_POOL_NAME}/${LAB_SEED_VOLUME},device=cdrom,readonly=on" \
    --network "network=${LAB_NETWORK_NAME},model=virtio,mac=${LAB_GUEST_MAC}" \
    --graphics spice \
    --video virtio \
    --osinfo detect=off,name=generic \
    --noautoconsole
}

wait_for_shutdown() {
  local i state
  for ((i = 0; i < 60; i++)); do
    state="$(vsh domstate "$LAB_DOMAIN" 2>/dev/null | tr -d '\r' || true)"
    case "$state" in
      "shut off" | "shutoff") return 0 ;;
    esac
    sleep 1
  done
  return 1
}

with_stopped_domain() {
  local was_running=false state
  state="$(vsh domstate "$LAB_DOMAIN" | tr -d '\r')"
  case "$state" in
    running)
      was_running=true
      vsh shutdown "$LAB_DOMAIN" >/dev/null
      wait_for_shutdown || fail "guest did not shut down within 60 seconds"
      ;;
    "shut off" | "shutoff") ;;
    *) fail "guest must be running or shut off for this operation (current state: $state)" ;;
  esac

  "$@"

  if [ "$was_running" = true ]; then
    vsh start "$LAB_DOMAIN" >/dev/null
  fi
}

confirm_destructive() {
  local action="$1" force="${2:-}"
  if [ "$force" = "--force" ]; then
    return 0
  fi
  if [ -n "$force" ]; then
    fail "unknown option '$force'; expected --force"
  fi
  if [ ! -t 0 ]; then
    fail "$action is destructive; re-run with --force in a non-interactive shell"
  fi

  printf '%s [y/N] ' "$action" >&2
  read -r answer
  case "$answer" in
    y | Y | yes | YES) ;;
    *) fail "cancelled" ;;
  esac
}

delete_guest_state() {
  if domain_exists; then
    case "$(vsh domstate "$LAB_DOMAIN" | tr -d '\r')" in
      "shut off" | "shutoff") ;;
      *) vsh destroy "$LAB_DOMAIN" >/dev/null ;;
    esac
    vsh undefine "$LAB_DOMAIN" --managed-save --snapshots-metadata >/dev/null 2>&1 || vsh undefine "$LAB_DOMAIN" >/dev/null
  fi

  if pool_exists; then
    volume_exists "$LAB_SEED_VOLUME" && vsh vol-delete "$LAB_SEED_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null
    volume_exists "$LAB_GUEST_VOLUME" && vsh vol-delete "$LAB_GUEST_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null
  fi
  forget_guest_host_key
}

cmd_doctor() {
  local status=0
  printf 'KVM device:      '
  if [ -e /dev/kvm ]; then
    printf 'ok\n'
  else
    printf 'missing\n'
    status=1
  fi

  printf 'libvirt URI:     %s\n' "$LAB_URI"
  if vsh uri >/dev/null 2>&1; then
    printf 'libvirt access:  ok\n'
  else
    printf 'libvirt access:  unavailable\n'
    status=1
  fi

  printf 'profile:         AlmaLinux %s (%s)\n' "$LAB_IMAGE_VERSION" "$LAB_IMAGE_BUILD"
  printf 'domain:          %s\n' "$LAB_DOMAIN"
  printf 'guest address:   %s\n' "$LAB_GUEST_IP"
  printf 'guest resources: %s vCPU, %s MiB RAM, %s GiB disk\n' "$LAB_VCPUS" "$LAB_MEMORY_MIB" "$LAB_DISK_GIB"
  return "$status"
}

cmd_image() {
  require_profile "$1"
  require_libvirt
  ensure_base_volume
  vsh vol-info "$LAB_BASE_VOLUME" --pool "$LAB_POOL_NAME"
}

cmd_create() {
  require_profile "$1"
  require_kvm
  require_libvirt
  domain_exists && fail "domain '$LAB_DOMAIN' already exists; use 'lab status almalinux' or 'lab reset almalinux'"

  ensure_pool
  ensure_network
  ensure_key
  forget_guest_host_key
  ensure_base_volume

  if volume_exists "$LAB_GUEST_VOLUME" || volume_exists "$LAB_SEED_VOLUME"; then
    fail "orphaned guest volumes exist; run 'lab delete almalinux --force' before creating again"
  fi

  create_guest_volume
  create_seed_volume
  if ! create_domain; then
    vsh vol-delete "$LAB_SEED_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null 2>&1 || true
    vsh vol-delete "$LAB_GUEST_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null 2>&1 || true
    fail "failed to define AlmaLinux guest"
  fi

  info "created and started '$LAB_DOMAIN'"
  info "SSH:         lab ssh almalinux"
  info "boot view:   lab open almalinux"
}

cmd_start() {
  local state
  require_profile "$1"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist; run 'lab create almalinux'"
  ensure_network

  state="$(vsh domstate "$LAB_DOMAIN" | tr -d '\r')"
  case "$state" in
    running) info "'$LAB_DOMAIN' is already running" ;;
    "shut off" | "shutoff") vsh start "$LAB_DOMAIN" ;;
    *) fail "cannot start '$LAB_DOMAIN' from state '$state'" ;;
  esac
}

cmd_stop() {
  local state
  require_profile "$1"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"

  state="$(vsh domstate "$LAB_DOMAIN" | tr -d '\r')"
  case "$state" in
    "shut off" | "shutoff") info "'$LAB_DOMAIN' is already stopped" ;;
    running)
      vsh shutdown "$LAB_DOMAIN"
      wait_for_shutdown || fail "guest did not shut down within 60 seconds; use virsh destroy only if you accept a hard power-off"
      ;;
    *) fail "cannot request a clean shutdown from state '$state'; inspect it with 'lab status almalinux'" ;;
  esac
}

cmd_status() {
  require_profile "$1"
  require_libvirt
  printf 'Profile:      AlmaLinux %s (%s)\n' "$LAB_IMAGE_VERSION" "$LAB_IMAGE_BUILD"
  printf 'Domain:       %s\n' "$LAB_DOMAIN"
  printf 'Guest IP:     %s\n' "$LAB_GUEST_IP"
  printf 'Storage pool: %s\n' "$LAB_POOL_NAME"

  if domain_exists; then
    vsh dominfo "$LAB_DOMAIN"
    printf '\nDisks:\n'
    vsh domblklist "$LAB_DOMAIN"
  else
    printf 'State:        not created\n'
  fi
}

cmd_ssh() {
  require_profile "$1"
  shift || true
  if [ "${1:-}" = "--" ]; then shift; fi
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"
  ensure_key
  [ "$(vsh domstate "$LAB_DOMAIN" | tr -d '\r')" = "running" ] || fail "domain '$LAB_DOMAIN' is not running"

  info "connecting to ${LAB_GUEST_USER}@${LAB_GUEST_IP}; first boot can take a short time"
  exec ssh \
    -i "$(key_path)" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$(known_hosts_path)" \
    -o ConnectTimeout=5 \
    "${LAB_GUEST_USER}@${LAB_GUEST_IP}" \
    "$@"
}

cmd_console() {
  require_profile "$1"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"
  exec virsh --connect "$LAB_URI" console "$LAB_DOMAIN"
}

cmd_open() {
  require_profile "$1"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"
  exec virt-manager --connect "$LAB_URI" --show-domain-console "$LAB_DOMAIN"
}

snapshot_create_impl() {
  local name="$1"
  vsh snapshot-create-as "$LAB_DOMAIN" "$name" --description "virtualization-lab snapshot: $name" --atomic >/dev/null
  info "created internal snapshot '$name'"
}

cmd_snapshot() {
  local name
  require_profile "$1"
  name="${2:-}"
  [ -n "$name" ] || fail "snapshot name is required"
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || fail "snapshot name may contain only letters, digits, '.', '_' and '-'"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"
  vsh snapshot-info "$LAB_DOMAIN" "$name" >/dev/null 2>&1 && fail "snapshot '$name' already exists"
  with_stopped_domain snapshot_create_impl "$name"
}

cmd_snapshots() {
  require_profile "$1"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"
  vsh snapshot-list "$LAB_DOMAIN"
}

snapshot_revert_impl() {
  local name="$1"
  vsh snapshot-revert "$LAB_DOMAIN" "$name" >/dev/null
  info "reverted '$LAB_DOMAIN' to snapshot '$name'"
}

cmd_revert() {
  local name
  require_profile "$1"
  name="${2:-}"
  [ -n "$name" ] || fail "snapshot name is required"
  require_libvirt
  domain_exists || fail "domain '$LAB_DOMAIN' does not exist"
  vsh snapshot-info "$LAB_DOMAIN" "$name" >/dev/null 2>&1 || fail "snapshot '$name' does not exist"
  with_stopped_domain snapshot_revert_impl "$name"
}

cmd_delete() {
  require_profile "$1"
  require_libvirt
  confirm_destructive "Delete '$LAB_DOMAIN' and all of its guest data/snapshots?" "${2:-}"
  delete_guest_state
  info "deleted '$LAB_DOMAIN'; verified base image and dedicated SSH key were kept"
}

cmd_reset() {
  require_profile "$1"
  require_kvm
  require_libvirt
  confirm_destructive "Reset '$LAB_DOMAIN' to the pinned AlmaLinux base and erase all guest data/snapshots?" "${2:-}"
  delete_guest_state
  cmd_create almalinux
}

cmd_purge_image() {
  require_profile "$1"
  require_libvirt
  domain_exists && fail "delete '$LAB_DOMAIN' before purging its base image"
  if pool_exists && { volume_exists "$LAB_GUEST_VOLUME" || volume_exists "$LAB_SEED_VOLUME"; }; then
    fail "guest runtime volumes still exist; run 'lab delete almalinux --force' before purging the base image"
  fi

  confirm_destructive "Delete the cached and libvirt AlmaLinux base image?" "${2:-}"
  ensure_pool
  if volume_exists "$LAB_BASE_VOLUME"; then
    vsh vol-delete "$LAB_BASE_VOLUME" --pool "$LAB_POOL_NAME" >/dev/null
  fi
  rm -f "$(cache_dir)/$LAB_IMAGE_FILENAME" "$(cache_dir)/${LAB_IMAGE_FILENAME}.partial"
  info "purged pinned AlmaLinux base image; the next create/image command will download it again"
}

main() {
  case "${1:-}" in
    doctor)
      shift
      [ "$#" -eq 0 ] || fail "doctor takes no arguments"
      cmd_doctor
      ;;
    image)
      shift
      cmd_image "${1:-}"
      ;;
    create)
      shift
      cmd_create "${1:-}"
      ;;
    start)
      shift
      cmd_start "${1:-}"
      ;;
    stop)
      shift
      cmd_stop "${1:-}"
      ;;
    status)
      shift
      cmd_status "${1:-}"
      ;;
    ssh)
      shift
      cmd_ssh "$@"
      ;;
    console)
      shift
      cmd_console "${1:-}"
      ;;
    open)
      shift
      cmd_open "${1:-}"
      ;;
    snapshot)
      shift
      cmd_snapshot "${1:-}" "${2:-}"
      ;;
    snapshots)
      shift
      cmd_snapshots "${1:-}"
      ;;
    revert)
      shift
      cmd_revert "${1:-}" "${2:-}"
      ;;
    reset)
      shift
      cmd_reset "${1:-}" "${2:-}"
      ;;
    delete)
      shift
      cmd_delete "${1:-}" "${2:-}"
      ;;
    purge-image)
      shift
      cmd_purge_image "${1:-}" "${2:-}"
      ;;
    -h | --help | help | "") usage ;;
    *) usage >&2; fail "unknown command '$1'" ;;
  esac
}

main "$@"

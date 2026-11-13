#!/usr/bin/env bash
# Set up MiniMax H3 on the official Vast.ai ComfyUI template.
# Default: all known H3 models. Optional: ref2v or manager-only.
set -Eeuo pipefail
trap 'printf "Setup stopped at line %s. Re-run the script after fixing the error.\n" "$LINENO" >&2' ERR

die() { printf '%s\n' "$*" >&2; exit 1; }

# With no arguments, Vast provisioning schedules this setup after ComfyUI starts.
# Manual use: bash vast-h3-setup.sh all|ref2v|manager-only
if [[ $# -eq 0 ]]; then
  profile=${H3_SETUP_PROFILE:-all}
  case "$profile" in
    all|ref2v|manager-only) ;;
    *) die 'H3_SETUP_PROFILE must be all, ref2v, or manager-only.' ;;
  esac
  port=${H3_COMFY_PORT:-18188}
  [[ "$port" =~ ^[0-9]{1,5}$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 )) ||
    die 'H3_COMFY_PORT must be between 1 and 65535.'
  install -D -m 0755 -- "$0" /opt/vast-h3/setup.sh
  cat > /etc/supervisor/conf.d/vast-h3-setup.conf <<EOF
[program:vast-h3-setup]
command=/bin/bash /opt/vast-h3/setup.sh --after-ready $profile $port
autostart=true
autorestart=false
startsecs=0
stdout_logfile=/var/log/vast-h3-setup.log
redirect_stderr=true
EOF
  printf 'H3 setup scheduled after ComfyUI responds. Log: /var/log/vast-h3-setup.log\n'
  exit 0
fi

if [[ "$1" == --after-ready ]]; then
  profile=$2
  api="http://127.0.0.1:$3/system_stats"
  for attempt in {1..120}; do
    if curl -fsS --max-time 2 "$api" >/dev/null 2>&1; then
      exec /bin/bash "$0" "$profile"
    fi
    sleep 2
  done
  die "ComfyUI did not become ready at $api. Check the ComfyUI logs."
fi

profile=${1:-all}
case "$profile" in
  ref2v|all|manager-only) ;;
  *) die "Usage: bash $0 [ref2v|all|manager-only]" ;;
esac

comfy=${COMFY_DIR:-${WORKSPACE:-/workspace}/ComfyUI}
[[ -f "$comfy/main.py" ]] || die "ComfyUI not found at $comfy. Set COMFY_DIR to the existing installation."
cd "$comfy"
comfy=$(pwd -P)
exec 9>"$comfy/.h3-setup.lock"
flock -n 9 || die "H3 setup is already running."
command -v git >/dev/null
command -v curl >/dev/null
python=/venv/main/bin/python
[[ -x "$python" ]] || die "Official Vast Python was not found at $python."
"$python" -m pip --version
supervisorctl status comfyui

# Resolve the active listener and user folder from the running ComfyUI process.
mapfile -t settings < <("$python" - "$comfy" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
matches = []
for process in Path("/proc").glob("[0-9]*"):
    try:
        if (process / "cwd").resolve(strict=True) != root:
            continue
        args = (process / "cmdline").read_bytes().decode(errors="replace").split("\0")
    except OSError:
        continue
    if not args or "python" not in Path(args[0]).name:
        continue
    if not any(Path(arg).name == "main.py" for arg in args[1:]):
        continue
    matches.append(args)
if len(matches) != 1:
    sys.exit("Could not identify exactly one running ComfyUI Python process. Open ComfyUI first.")
args = matches[0]

def option(name, default):
    for index, arg in enumerate(args):
        if arg.startswith(name + "="):
            return arg.split("=", 1)[1]
        if arg == name:
            if index + 1 == len(args) or not args[index + 1] or args[index + 1].startswith("--"):
                return ""
            return args[index + 1]
    return default

print(option("--listen", "127.0.0.1"))
print(option("--port", "8188"))
print((root / option("--user-directory", "user")).resolve())
PY
)
[[ ${#settings[@]} -eq 3 ]] || die 'ComfyUI process detection failed.'
case "${settings[0]}" in
  127.0.0.1) loopback=127.0.0.1 ;;
  ::1) loopback='[::1]' ;;
  *) die 'Manager requires a loopback listener. Keep Vast Portal enabled and set ComfyUI --listen 127.0.0.1 before re-running.' ;;
esac
api="http://$loopback:${settings[1]}"
user_dir=${settings[2]}
curl -fsS --max-time 20 "$api/system_stats" >/dev/null
if [[ "$profile" != manager-only ]]; then
  curl -fsS --max-time 45 "$api/object_info" | "$python" -c '
import json, sys
nodes = json.load(sys.stdin)
required = {"MiniMaxH3ReferenceToVideo"}
if sys.argv[1] == "all":
    required.update(("MiniMaxH3ImageToVideo", "MiniMaxH3FunControlNetApply"))
missing = required - nodes.keys()
if missing:
    sys.exit("Required native H3 nodes missing: " + ", ".join(sorted(missing)))
' "$profile"
fi

# Verify the complete safetensors payload before it is visible to ComfyUI.
valid_model() {
  "$python" - "$1" <<'PY'
import json
import struct
import sys
from pathlib import Path

try:
    path = Path(sys.argv[1])
    with path.open("rb") as stream:
        length, = struct.unpack("<Q", stream.read(8))
        if not 2 <= length <= 100_000_000:
            sys.exit(1)
        tensors = json.loads(stream.read(length))
    end = max(item["data_offsets"][1] for key, item in tensors.items() if key != "__metadata__")
    sys.exit(0 if end > 0 and path.stat().st_size == 8 + length + end else 1)
except (OSError, ValueError, TypeError, KeyError, AttributeError, struct.error):
    sys.exit(1)
PY
}

download() {
  local repo=$1 remote=$2 target="models/$3" partial
  partial="$target.part"
  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" ]]; then
    valid_model "$target" || die "Existing file failed validation: $target. Move it aside and retry."
    printf 'Already complete: %s\n' "$target"
    return
  fi
  if ! valid_model "$partial"; then
    printf 'Downloading %s\n' "$target"
    curl --fail --location --retry 3 --connect-timeout 20 --continue-at - \
      --output "$partial" "https://huggingface.co/$repo/resolve/main/$remote"
    valid_model "$partial" || die "Incomplete or invalid file: $partial"
  fi
  mv -- "$partial" "$target"
}

# Change the active Manager config only. Keep a backup on the first edit.
"$python" - "$user_dir" "$comfy" <<'PY'
from pathlib import Path
import configparser
import os
import shutil
import sys
import tempfile

user, root = map(Path, sys.argv[1:])
override = os.environ.get("MANAGER_CONFIG")
candidates = [user / "__manager/config.ini",
              user / "default/ComfyUI-Manager/config.ini",
              root / "custom_nodes/ComfyUI-Manager/config.ini"]
if override:
    path = Path(override)
else:
    active = [path for path in candidates if path.is_file()]
    if len(active) != 1:
        sys.exit("Set MANAGER_CONFIG to the exact config.ini shown in ComfyUI startup logs.")
    path = active[0]
if not path.is_file():
    sys.exit(f"Manager configuration does not exist: {path}")
path = path.resolve()
config = configparser.ConfigParser(interpolation=None)
with path.open() as stream:
    config.read_file(stream)
if not config.has_section("default"):
    config.add_section("default")
settings = config["default"]
if settings.get("allow_git_url_install", "").lower() != "true" or settings.get("allow_pip_install", "").lower() != "true":
    backup = path.with_name(path.name + ".before-h3")
    if not backup.exists():
        shutil.copy2(path, backup)
    settings.update(allow_git_url_install="true", allow_pip_install="true")
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        config.write(stream)
    try:
        shutil.copymode(path, temporary)
        if os.geteuid() == 0:
            owner = path.stat()
            os.chown(temporary, owner.st_uid, owner.st_gid)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
print(f"Manager Git URL and pip flags saved in {path}")
PY

# Model manifest. Add one row per weight: group, Hugging Face repo, source path, destination under models/.
if [[ "$profile" != manager-only ]]; then
  mkdir -p models
  df -h models
  while IFS='|' read -r group repository source destination; do
    if [[ "$group" == ref2v || "$profile" == all ]]; then
      download "$repository" "$source" "${destination:-$source}"
    fi
  done <<'MODELS'
ref2v|Comfy-Org/MiniMax-H3|diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors|
ref2v|Comfy-Org/MiniMax-H3|text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors|
ref2v|Comfy-Org/MiniMax-H3|vae/minimax_h3_video_vae_fp16.safetensors|
ref2v|Comfy-Org/MiniMax-H3|vae/minimax_h3_audio_vae_fp32.safetensors|
ref2v|RunningHubAI/rh-minimax-h3-ref2v-turbo-8step-v1.0-768p-lora|minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16_r.safetensors|loras/minimax_h3_ref2v_turbo_8step_v1.0_768p_comfyui_bf16_r.safetensors
all|Comfy-Org/MiniMax-H3|loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors|
all|Comfy-Org/MiniMax-H3|diffusion_models/minimax_h3_fl2va_pruned_fp8_scaled.safetensors|
all|Comfy-Org/MiniMax-H3|loras/minimax_h3_fl2v_turbo_4step_v1.0_768p_comfyui_bf16.safetensors|
all|Comfy-Org/MiniMax-H3|model_patches/minimax_h3_fun_controlnet_union_pruned_int8_convrot.safetensors|
all|Comfy-Org/SDPose|checkpoints/sdpose_wholebody_fp16.safetensors|
all|Comfy-Org/SDPose|diffusion_models/rt_detr_v4-x-hgnet_fp16.safetensors|
MODELS
fi

supervisorctl restart comfyui
for attempt in {1..60}; do
  if curl -fsS --max-time 4 "$api/system_stats" >/dev/null 2>&1; then
    printf 'ComfyUI is responding. Open Manager to check Git URL and pip options, then select the downloaded models in the workflow.\n'
    exit 0
  fi
  sleep 2
done
die 'ComfyUI did not respond after restart. Check supervisorctl status comfyui and the instance logs.'

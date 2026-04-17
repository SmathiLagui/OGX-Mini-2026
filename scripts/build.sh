#!/usr/bin/env bash
# OGX-Mini 2026 firmware build script (Linux / macOS)
# Run from anywhere. Creates scripts/build/ and runs CMake/Ninja there; source is Firmware/RP2040. Optional log in scripts/ on failure.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIRMWARE_RP2040="$REPO_ROOT/Firmware/RP2040"

if [ ! -f "$FIRMWARE_RP2040/CMakeLists.txt" ]; then
  echo "Error: Firmware/RP2040/CMakeLists.txt not found. Run this script from the OGX-Mini-2026 repo (scripts/ folder)."
  exit 1
fi

BOARDS=(
  "PI_PICO:Pi Pico"
  "PI_PICO2:Pi Pico 2"
  "PI_PICOW:Pi Pico W"
  "PI_PICO2W:Pi Pico 2 W"
  "RP2040_ZERO:Waveshare RP2040-Zero"
  "RP2350_ZERO:Waveshare RP2350-Zero"
  "RP2350_USB_A:Waveshare RP2350-USB-A"
  "RP2040_XIAO:Seeed Studio XIAO RP2040"
  "RP2354:RP2354"
  "ADAFRUIT_FEATHER:Adafruit Feather USB Host"
  "EXTERNAL_4CH_I2C:External 4CH I2C"
  "ESP32_BLUEPAD32_I2C:ESP32 Bluepad32 I2C"
  "ESP32_BLUERETRO_I2C:ESP32 BlueRetro I2C"
)

FIXED_DRIVERS=(
  "XINPUT:Xbox 360 (XInput)"
  "XBOXOG:Original Xbox (Gamepad)"
  "PS3:PlayStation 3"
  "SWITCH:Nintendo Switch Pro"
  "WIIU:Wii U (GameCube Adapter)"
  "WII:Wii (Wiimote)"
  "PS1PS2:PlayStation 1/2 (GPIO)"
  "GAMECUBE:GameCube (GPIO)"
  "DREAMCAST:Dreamcast (GPIO)"
  "N64:Nintendo 64 (GPIO)"
  "DINPUT:DInput"
  "PSCLASSIC:PlayStation Classic"
  "WEBAPP:Web App"
)

check_cmd() { command -v "$1" &>/dev/null; }
check_python_module() { python3 -c "import $1" &>/dev/null 2>&1; }
check_pkg_config() { check_cmd pkg-config && pkg-config --exists "$1" &>/dev/null 2>&1; }

echo "=== OGX-Mini 2026 Build Script ==="
echo ""

# --- Prerequisites ---
declare -A MISSING_PKGS  # maps label -> "apt:X dnf:X pacman:X msys2:X brew:X"
check_cmd git                    || MISSING_PKGS[git]="apt:git dnf:git pacman:git msys2:git brew:git"
check_cmd pkg-config             || MISSING_PKGS[pkg-config]="apt:pkg-config dnf:pkgconf-pkg-config pacman:pkgconf msys2:mingw-w64-x86_64-pkgconf brew:pkg-config"
check_cmd python3                || MISSING_PKGS[python3]="apt:python3 dnf:python3 pacman:python msys2:mingw-w64-x86_64-python brew:python"
check_cmd cmake                  || MISSING_PKGS[cmake]="apt:cmake dnf:cmake pacman:cmake msys2:mingw-w64-x86_64-cmake brew:cmake"
check_cmd ninja                  || MISSING_PKGS[ninja]="apt:ninja-build dnf:ninja-build pacman:ninja msys2:mingw-w64-x86_64-ninja brew:ninja"
check_cmd gcc                    || MISSING_PKGS[gcc]="apt:gcc dnf:gcc pacman:gcc msys2:mingw-w64-x86_64-gcc brew:gcc"
check_cmd g++                    || MISSING_PKGS[g++]="apt:g++ dnf:gcc-c++ pacman:gcc msys2:mingw-w64-x86_64-gcc brew:gcc"
check_cmd arm-none-eabi-gcc      || MISSING_PKGS[arm-none-eabi-gcc]="apt:gcc-arm-none-eabi dnf:arm-none-eabi-gcc-cs pacman:arm-none-eabi-gcc msys2:mingw-w64-x86_64-arm-none-eabi-gcc brew:arm-none-eabi-gcc"
check_cmd arm-none-eabi-gcc && {
  echo "" | arm-none-eabi-gcc -x c -include ctype.h -fsyntax-only - &>/dev/null || \
    MISSING_PKGS[libnewlib]="apt:libnewlib-arm-none-eabi dnf:arm-none-eabi-newlib pacman:arm-none-eabi-newlib msys2:mingw-w64-x86_64-arm-none-eabi-newlib"
  echo "" | arm-none-eabi-g++ -x c++ -include cstdlib -fsyntax-only - &>/dev/null || \
    MISSING_PKGS[libstdc++-arm]="apt:libstdc++-arm-none-eabi-newlib dnf:arm-none-eabi-gcc-cs-c++ pacman:arm-none-eabi-newlib msys2:mingw-w64-x86_64-arm-none-eabi-newlib"
} || {
  MISSING_PKGS[libnewlib]="apt:libnewlib-arm-none-eabi dnf:arm-none-eabi-newlib pacman:arm-none-eabi-newlib msys2:mingw-w64-x86_64-arm-none-eabi-newlib"
  MISSING_PKGS[libstdc++-arm]="apt:libstdc++-arm-none-eabi-newlib dnf:arm-none-eabi-gcc-cs-c++ pacman:arm-none-eabi-newlib"
}
check_pkg_config libusb-1.0      || MISSING_PKGS[libusb]="apt:libusb-1.0-0-dev dnf:libusb-devel pacman:libusb msys2:mingw-w64-x86_64-libusb brew:libusb"
check_python_module Cryptodome   || MISSING_PKGS[pycryptodomex]="apt:python3-pycryptodome dnf:python3-pycryptodomex pacman:python-pycryptodomex msys2:mingw-w64-x86_64-python-pycryptodomex brew:\"pip3 install pycryptodomex\""

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "Missing required tools: ${!MISSING_PKGS[*]}"
  echo ""
  echo "Install instructions:"

  get_pkgs() {
    local prefix="$1" pkgs=()
    for entry in "${MISSING_PKGS[@]}"; do
      for token in $entry; do
        if [[ "$token" == "$prefix:"* ]]; then
          pkgs+=("${token#*:}")
        fi
      done
    done
    echo "${pkgs[*]}"
  }

  if [ -n "$MSYSTEM" ] && check_cmd pacman; then
    echo "  MSYS2 MinGW64:  pacman -S $(get_pkgs msys2)"
    echo "  Make sure you are running this script in the MSYS2 MinGW64 shell."
  elif check_cmd apt-get; then
    echo "  Debian/Ubuntu:  sudo apt install $(get_pkgs apt)"
  elif check_cmd dnf; then
    echo "  Fedora:         sudo dnf install $(get_pkgs dnf)"
  elif check_cmd pacman; then
    echo "  Arch:           sudo pacman -S $(get_pkgs pacman)"
  elif check_cmd brew; then
    echo "  macOS (Homebrew): brew install $(get_pkgs brew)"
  else
    echo "  Install: git, gcc, python3, cmake, ninja, arm-none-eabi-gcc, libusb, and pycryptodomex."
    echo "  See README.md in the project root for details."
  fi
  echo ""
  read -r -p "Exit now? [Y/n] " ans
  case "${ans:-Y}" in [nN]) ;; *) exit 1;; esac
fi

# --- Board selection ---
echo "Select board:"
for i in "${!BOARDS[@]}"; do
  IFS=: read -r id desc <<< "${BOARDS[$i]}"
  echo "  $((i+1))) $desc ($id)"
done
echo "  $(( ${#BOARDS[@]} + 1 ))) Cancel"
read -r -p "Choice [1-${#BOARDS[@]}]: " board_choice
if [ "$board_choice" = "$(( ${#BOARDS[@]} + 1 ))" ]; then echo "Cancelled."; exit 0; fi
if [ "$board_choice" -lt 1 ] || [ "$board_choice" -gt ${#BOARDS[@]} ]; then echo "Invalid choice."; exit 1; fi
IFS=: read -r OGXM_BOARD _ <<< "${BOARDS[$((board_choice-1))]}"

# --- Combo vs fixed driver ---
echo ""
echo "Build type:"
echo "  1) Default (combos enabled, all modes selectable)"
echo "  2) Fixed output mode (combos disabled, single mode)"
read -r -p "Choice [1-2]: " build_type_choice
OGXM_FIXED_DRIVER=""
if [ "$build_type_choice" = "2" ]; then
  echo "Select fixed output mode:"
  for i in "${!FIXED_DRIVERS[@]}"; do
    IFS=: read -r id desc <<< "${FIXED_DRIVERS[$i]}"
    echo "  $((i+1))) $desc ($id)"
  done
  echo "  $(( ${#FIXED_DRIVERS[@]} + 1 ))) Cancel"
  read -r -p "Choice [1-${#FIXED_DRIVERS[@]}]: " driver_choice
  if [ "$driver_choice" = "$(( ${#FIXED_DRIVERS[@]} + 1 ))" ]; then echo "Cancelled."; exit 0; fi
  if [ "$driver_choice" -lt 1 ] || [ "$driver_choice" -gt ${#FIXED_DRIVERS[@]} ]; then echo "Invalid choice."; exit 1; fi
  IFS=: read -r OGXM_FIXED_DRIVER _ <<< "${FIXED_DRIVERS[$((driver_choice-1))]}"
fi

# --- Release vs Debug ---
echo ""
echo "Build configuration:"
echo "  1) Release (smaller, faster)"
echo "  2) Debug (UART logging, no optimization)"
read -r -p "Choice [1-2]: " config_choice
if [ "$config_choice" = "2" ]; then
  CMAKE_BUILD_TYPE=Debug
else
  CMAKE_BUILD_TYPE=Release
fi

OGXM_SWITCH2_HID_RAW_LOG=OFF
if [ "$config_choice" = "2" ]; then
  echo ""
  echo "Switch 2 Pro USB (PID 0x2069) debugging (Debug builds only):"
  echo "  1) Off (default)"
  echo "  2) UART: raw HID hex when report buffer changes (-DOGXM_SWITCH2_HID_RAW_LOG=ON)"
  read -r -p "Choice [1-2]: " s2_raw_choice
  if [ "$s2_raw_choice" = "2" ]; then
    OGXM_SWITCH2_HID_RAW_LOG=ON
  fi
fi

# --- Run build ---
BUILD_DIR="$SCRIPT_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo ""
echo "Building: board=$OGXM_BOARD type=$CMAKE_BUILD_TYPE ${OGXM_FIXED_DRIVER:+fixed=$OGXM_FIXED_DRIVER}${OGXM_SWITCH2_HID_RAW_LOG:+ switch2_raw_hid=ON}"
echo "Output directory: $BUILD_DIR"
echo ""

BUILD_LOG=$(mktemp)
trap "rm -f '$BUILD_LOG'" EXIT

(
  cd "$BUILD_DIR"
  CMAKE_ARGS=(-G Ninja -DOGXM_BOARD="$OGXM_BOARD" -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" -DPython3_EXECUTABLE="$(which python3)")
  [ -n "$OGXM_FIXED_DRIVER" ] && CMAKE_ARGS+=(-DOGXM_FIXED_DRIVER="$OGXM_FIXED_DRIVER" -DOGXM_FIXED_DRIVER_ALLOW_COMBOS=OFF)
  [ "$OGXM_SWITCH2_HID_RAW_LOG" = "ON" ] && CMAKE_ARGS+=(-DOGXM_SWITCH2_HID_RAW_LOG=ON)
  cmake "${CMAKE_ARGS[@]}" "$FIRMWARE_RP2040"
  ninja
) 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}

if [ "$BUILD_STATUS" -eq 0 ]; then
  echo ""
  echo "Build completed successfully. Output is in: $BUILD_DIR"
  if [ "$CMAKE_BUILD_TYPE" = "Debug" ]; then
    echo ""
    echo "Debug logging (OGXM_LOG, Switch 2 raw HID): UART only at 115200 8N1 — not the Pico USB cable."
    case "$OGXM_BOARD" in
      PI_PICOW|PI_PICO2W) echo "  Wire USB-serial RX to GP4 (board TX), GND to GND. (UART1; avoids PIO USB on GP0/1.)" ;;
      *) echo "  Wire USB-serial RX to GP0 (board TX), GND to GND." ;;
    esac
    echo "  Then: minicom -D /dev/ttyUSB0 -b 115200   (or screen, PuTTY, VS Code Serial Monitor)"
  fi
else
  echo ""
  echo "Build failed. You can save the output to a log file for troubleshooting."
  read -r -p "Save log to $SCRIPT_DIR/build_log.txt? [y/N] " save_log
  case "${save_log:-N}" in
    [yY]|[yY][eE][sS])
      cp "$BUILD_LOG" "$SCRIPT_DIR/build_log.txt"
      echo "Log saved to $SCRIPT_DIR/build_log.txt"
      ;;
  esac
  exit 1
fi

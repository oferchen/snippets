#!/usr/bin/env bash
#
# mac_classifier.sh - Classify MAC addresses per IEEE/IETF/IANA standards
#
# Usage:
#   mac_classifier.sh -m <mac>           # Classify a single MAC address
#   mac_classifier.sh -f <file>          # Classify MACs from file (one per line)
#   mac_classifier.sh -m <mac> -v        # Verbose output with trace
#   mac_classifier.sh -f <file> -v       # Verbose trace from file
#
# Classification categories:
#   - Broadcast (ff:ff:ff:ff:ff:ff)
#   - IEEE reserved (e.g. STP, LACP, LLDP, MSTP)
#   - Cisco protocol-specific (PVST, CGMP, VTP, EIGRP, etc.)
#   - IPv4 multicast (01:00:5e:xx:xx:xx)
#   - IPv6 multicast (33:33:xx:xx:xx:xx)
#   - Locally administered unicast (virtual)
#   - Globally administered unicast (physical)
#   - Locally administered multicast
#   - Globally administered multicast
#
# Bit logic:
#   - Bit 0 (LSB of first byte) = 1 → Multicast
#   - Bit 1 = 1 → Locally Administered (virtual)
#   - Bit 1 = 0 → Globally Administered (OUI)

set -euo pipefail
shopt -s nocasematch nullglob

VERBOSE=0

log() {
  [[ "$VERBOSE" -eq 1 ]] && echo "$@"
}

normalize_mac() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^0-9a-f]//g' | sed -E 's/(..)/\1:/g;s/:$//'
}

classify_mac() {
  local raw_mac="$1"
  local mac
  mac=$(normalize_mac "$raw_mac")
  local first_byte_hex="${mac%%:*}"
  local first_byte=$((16#$first_byte_hex))
  local oui_prefix=${mac:0:8}

  log "Analyzing MAC: $mac"

  if [[ "$mac" == "ff:ff:ff:ff:ff:ff" ]]; then
    echo "$mac - Broadcast"
    return
  fi

  case "$mac" in
    01:80:c2:00:00:00) echo "$mac - IEEE STP (Spanning Tree Protocol)"; return ;;
    01:80:c2:00:00:01) echo "$mac - IEEE Pause Frame"; return ;;
    01:80:c2:00:00:02) echo "$mac - IEEE Bridge Port Management"; return ;;
    01:80:c2:00:00:04) echo "$mac - IEEE GVRP"; return ;;
    01:80:c2:00:00:05) echo "$mac - IEEE GMRP"; return ;;
    01:80:c2:00:00:06) echo "$mac - IEEE MSTP"; return ;;
    01:80:c2:00:00:08) echo "$mac - IEEE Provider Bridge (Q-in-Q)"; return ;;
    01:80:c2:00:00:09) echo "$mac - IEEE LACP"; return ;;
    01:80:c2:00:00:0a) echo "$mac - IEEE Ethernet OAM"; return ;;
  esac

  case "$mac" in
    01:00:0c:cc:cc:cc) echo "$mac - Cisco PVST (STP variant)"; return ;;
    01:00:0c:cc:cc:cd) echo "$mac - Cisco CGMP"; return ;;
    01:00:0c:cc:cc:ce) echo "$mac - Cisco VTP"; return ;;
    01:00:0c:cc:cc:cf) echo "$mac - Cisco DTP"; return ;;
    01:00:0c:cd:cd:cd) echo "$mac - Cisco Loop Detection"; return ;;
    01:00:0c:cd:cd:01) echo "$mac - Cisco EIGRP"; return ;;
  esac

  if [[ "$oui_prefix" == "01:00:5e" ]]; then
    echo "$mac - IPv4 Multicast"
    return
  fi

  if [[ "${mac:0:5}" == "33:33" ]]; then
    echo "$mac - IPv6 Multicast"
    return
  fi

  local is_multicast=$((first_byte & 0x01))
  local is_local=$((first_byte & 0x02))

  if [[ "$is_multicast" -eq 1 && "$is_local" -eq 1 ]]; then
    echo "$mac - Locally Administered Multicast"
  elif [[ "$is_multicast" -eq 1 ]]; then
    echo "$mac - Globally Administered Multicast"
  elif [[ "$is_local" -eq 1 ]]; then
    echo "$mac - Locally Administered Unicast (Virtual)"
  else
    echo "$mac - Globally Administered Unicast (Physical)"
  fi
}

main() {
  local mac=""
  local file=""

  while getopts ":m:f:v" opt; do
    case "$opt" in
      m) mac="$OPTARG" ;;
      f) file="$OPTARG" ;;
      v) VERBOSE=1 ;;
      *) echo "Invalid option"; exit 1 ;;
    esac
  done

  if [[ -n "$mac" ]]; then
    classify_mac "$mac"
  elif [[ -n "$file" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      classify_mac "$line"
    done < "$file"
  else
    echo "Usage: $0 -m <mac> | -f <file> [-v]" >&2
    exit 2
  fi
}

main "$@"

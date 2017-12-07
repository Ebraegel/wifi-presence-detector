#!/bin/bash

set -u

WPD_LOCKFILE="${WPD_LOCKFILE:=/tmp/scan_network.lock}"
WPD_LOGFILE="${WPD_LOGFILE:=scan.log}"
WPD_CONSECUTIVE_EMPTY_RESULT_THRESHOLD="${WPD_CONSECUTIVE_EMPTY_SCAN_THRESHOLD:=20}"
WPD_SLEEP_INTERVAL="${WPD_SLEEP_INTERVAL:=5}"
WPD_SCAN_SUBNET="${WPD_SCAN_SUBNET:=192.168.1.1/24}"

consecutive_empty_result_count=0
scan_result=''
last_post=''

timestamp() {
  date '+%Y-%m-%d %H:%M:%S%z'
}

log() {
echo "$(timestamp) :: $*" >> "$WPD_LOGFILE"
}

post_to_ifttt() {
  curl -s -XPOST "https://maker.ifttt.com/trigger/${1}/with/key/${IFTTT_WEBHOOK_KEY}" >>" $WPD_LOGFILE"
  log ""
}

scan() {
  log "Starting scan of $WPD_SCAN_SUBNET"
  if sudo nmap -sn "$WPD_SCAN_SUBNET" | grep -if known_mac_addresses >> "$WPD_LOGFILE"; then
    scan_result='someone_home'
  else
    scan_result='no_one_home'
  fi
  log "Got scan result [${scan_result}]"
}

post_if_state_changed() {
  # No need to re-post the same status if it hasn't changed
  # Although if it's the first run, last_post should be empty
  # so we'll always post because there's no way of knowing (in this script)
  # what the current status is
  # Bad things (or at least noisy things) will probably happen if more than one of the script run at once, hence the flocking in main()

  if [[ "$scan_result" != "$last_post" ]]; then
    log "Posting scan result [${scan_result}] to ifttt because it was different than the last posted result: [${last_post}]"
    post_to_ifttt $scan_result
  else
    log "Skipping ifttt post because scan result [${scan_result}] was the same as our last post [${last_post}]"
  fi
  last_post=$scan_result
}

handle_scan_result() {
  if [[ "$scan_result" == "someone_home" ]]; then
    log "Got a [${scan_result}], resetting consecutive empty result count to 0"
    consecutive_empty_result_count=0
    post_if_state_changed
  elif [[ "$scan_result" == "no_one_home" ]]; then
    ((consecutive_empty_result_count++))
    if [[ "$consecutive_empty_result_count" -gt "$WPD_CONSECUTIVE_EMPTY_RESULT_THRESHOLD" ]]; then
      post_if_state_changed
    else
       log "Consecutive empty result count [${consecutive_empty_result_count}] <= threshold [${WPD_CONSECUTIVE_EMPTY_RESULT_THRESHOLD}], skipping post to ifttt"
    fi
  fi
}

scan_forever() {
  while :; do
    scan
    handle_scan_result
    sleep $WPD_SLEEP_INTERVAL
  done
}

check_dependencies() {
  command -v nmap &>/dev/null || { echo "nmap is required but not installed, bailing out!"; exit 1; }
  command -v flock &>/dev/null || { echo "flock is required but not installed, bailing out!"; exit 1; }
  command -v curl &>/dev/null || { echo "curl is required but not installed, bailing out!"; exit 1; }
 }

main() {
  [[ $(id -u) -eq 0 ]] || { echo "Script must be run as root - bailing out!"; log "Script must be run as root - bailing out!"; exit 1; }
  cd "$(dirname "$0")"
  . .env

  # Ensure only one copy of the script can run at a time
  # Exact usage courtesy of http://mywiki.wooledge.org/BashFAQ/045
  exec 200>"$WPD_LOCKFILE"
  if ! flock -n 200  ; then
     echo "another instance of wifi-presence-detector is running";
     exit 0
  fi

  check_dependencies
  scan_forever
}

main


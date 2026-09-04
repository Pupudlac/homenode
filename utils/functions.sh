#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Shared helper functions for logging and execution.
# ==============================================================================
# Requires colors.sh to be sourced first.

log_info()  { echo -e "${YELLOW}[INFO]${RESET} $1"; }
log_ok()    { echo -e "${GREEN}[ OK ]${RESET} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err()   { echo -e "${RED}[ERR ]${RESET} $1"; }

# Executes a command unless DRY_RUN is set to true in config.sh
run() {
  if [ "${DRY_RUN:-false}" = true ]; then
    echo -e "${BLUE}[DRY-RUN]${RESET} $*"
  else
    eval "$*"
  fi
}
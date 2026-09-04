#!/bin/bash
# ==============================================================================
# Project:   HomeNode
# Authors:   René & AI Architect
# Description: Defines color codes for terminal output.
# ==============================================================================

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'     # No Color (standard)
RESET='\033[0m'  # Alias for RESET

# === Basic Logging Functions (Fallback) ===
# Note: Advanced logging is in functions.sh, these are here just in case
# colors.sh is sourced independently.
log_info()  { echo -e "${YELLOW}[INFO]${RESET} $1"; }
log_ok()    { echo -e "${GREEN}[ OK ]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1"; }
log_step()  { echo -e "${CYAN}➤ $1${RESET}"; }
#!/bin/bash

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'


INSTALL_DIR="/opt/hbtec/tools"

echo
echo "==========================================="
echo " hbTec SpectrumKNX Manager Installer @cko"
echo "==========================================="
echo

sudo mkdir -p "$INSTALL_DIR"

sudo cp scripts/spectrumknx-install.sh \
    "$INSTALL_DIR/"

sudo cp scripts/spectrumknx-manager.sh \
    "$INSTALL_DIR/"

sudo cp VERSION \
    "$INSTALL_DIR/"


sudo chmod +x \
    "$INSTALL_DIR/spectrumknx-install.sh"

sudo chmod +x \
    "$INSTALL_DIR/spectrumknx-manager.sh"

sudo ln -sf \
    "$INSTALL_DIR/spectrumknx-manager.sh" \
    /usr/local/bin/sknx


echo
echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} hbTec SpectrumKNX Manager installiert${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo "Nächster Schritt:"
echo
echo -e  "   ${GREEN} sknx${NC}"
echo
echo "Startet den SpectrumKNX Manager."
echo


#!/usr/bin/env bash
# Quick start: gate-core → gate-server → gate-cli
#
# This shows how to go from zero to a running gate ecosystem
# using gate-cli as the operator interface.
#
# Prerequisites:
#   pip install maelstrom-gate gate-server gate-cli
#
# Seeded by Creator 2 (gate-cli), Loop 5.

set -euo pipefail

echo "=== Maelstrom Gate Quick Start ==="
echo ""

# 1. Start gate-server
echo "Starting gate-server on port 8900..."
python -m gate_server &
SERVER_PID=$!
sleep 2

# 2. Check health via CLI
echo "Checking server health..."
gate server health

# 3. Register tools from YAML
echo "Registering example tools..."
gate tools register -f examples/tools.yaml

# 4. Show what's visible at different threat levels
echo ""
echo "=== Normal operations (mode 0.2) ==="
gate tools filter --mode 0.2

echo ""
echo "=== Elevated threat (mode 0.6) ==="
gate tools filter --mode 0.6

echo ""
echo "=== Crisis mode (mode 0.9) ==="
gate tools filter --mode 0.9

# 5. Build and verify an authorization envelope
echo ""
echo "=== Authorization envelope ==="
gate -o json envelope build --tool read_logs --mode 0.3 > /tmp/envelope.json
gate envelope verify -f /tmp/envelope.json

# 6. Show ecosystem status
echo ""
gate status

# Cleanup
kill $SERVER_PID 2>/dev/null
echo ""
echo "=== Done ==="

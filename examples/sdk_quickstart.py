#!/usr/bin/env python3
"""gate-sdk quickstart — get gating in 15 lines.

Copy this into your project to start filtering AI tools by threat level.
Requires: pip install maelstrom-gate gate-sdk

STUB — provided by Creator 1 (gate-sdk) as a quickstart for gate-core users.
"""
from gate_sdk import GateClient

# 1. Create a client
client = GateClient(mode=0.0)

# 2. Register your tools with execution classes
client.add_tool("read_file",   "read_only",       "Read a source file")
client.add_tool("search",      "read_only",       "Search the codebase")
client.add_tool("write_file",  "state_mutation",   "Write to a file")
client.add_tool("deploy",      "high_impact",      "Deploy to production")
client.add_tool("send_slack",  "external_action",  "Send a Slack message")

# 3. Filter at different threat levels
for mode in [0.0, 0.4, 0.7, 1.0]:
    result = client.filter(mode)
    print(f"mode={mode:.1f}: {result.visible_names}")

# Output:
#   mode=0.0: ['deploy', 'read_file', 'search', 'send_slack', 'write_file']
#   mode=0.4: ['read_file', 'search', 'send_slack', 'write_file']
#   mode=0.7: ['read_file', 'search']
#   mode=1.0: ['read_file', 'search']

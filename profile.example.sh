# Bifrost profile example (safe to commit)
# Copy this file to ~/.config/bifrost/profile.sh and replace values with your real hosts.
# SERVER_ENTRIES format: "name|host|user|port"
# ALIAS_ENTRIES format: "alias|server-name"

SERVER_ENTRIES=(
	"example-prod|203.0.113.10|admin|22"
	"example-dev|198.51.100.20|devuser|22"
)

ALIAS_ENTRIES=(
	"prod|example-prod"
	"dev|example-dev"
)

# Legacy format is still supported by bifrost.sh if needed:
# SRVNAME=()
# SRVHOST=()
# SRVUSER=()
# SRVPORT=()
# ALIAS_NAME=()
# ALIAS_TARGET=()

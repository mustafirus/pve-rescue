IP=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | tr '\n' ' ')
echo "  IP: ${IP:-'no network yet'}"
echo "  Kernel: $(uname -r)"
echo ""

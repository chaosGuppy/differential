set -e
echo "Installing project dependencies..."
uv sync

echo "Installing global tools..."
uv tool install pyright

#!/usr/bin/env bash

echo "Running Dock-Rust diagnostics..."

echo

command -v docker >/dev/null \
&& echo "✔ Docker installed" \
|| echo "❌ Docker missing"


command -v git >/dev/null \
&& echo "✔ Git installed" \
|| echo "❌ Git missing"


command -v bun >/dev/null \
&& echo "✔ Bun installed" \
|| echo "⚠ Bun missing"


command -v cargo >/dev/null \
&& echo "✔ Rust installed" \
|| echo "⚠ Rust missing"
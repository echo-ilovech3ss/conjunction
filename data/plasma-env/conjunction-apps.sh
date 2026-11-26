#!/bin/sh
# Sourced by Plasma Wayland startup (/etc/xdg/plasma-workspace/env/)
_conj_xdg="${XDG_DATA_HOME:-$HOME/.local/share}/conjunction/xdg"
case ":${XDG_DATA_DIRS:-}:" in
    *":$_conj_xdg:"*) ;;
    *) export XDG_DATA_DIRS="$_conj_xdg:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
esac
unset _conj_xdg

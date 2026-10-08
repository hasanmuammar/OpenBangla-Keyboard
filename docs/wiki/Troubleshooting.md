# Troubleshooting

## OpenBangla does not appear in GNOME Input Sources

Check the IBus registry:

```bash
ibus list-engine | grep -i -A3 -B2 openbangla
```

If OpenBangla is missing, rebuild the user-local component cache:

```bash
export IBUS_COMPONENT_PATH="$HOME/.local/share/ibus/component:/usr/share/ibus/component"
dbus-update-activation-environment --systemd "IBUS_COMPONENT_PATH=$IBUS_COMPONENT_PATH"
IBUS_COMPONENT_PATH="$IBUS_COMPONENT_PATH" ibus write-cache
IBUS_COMPONENT_PATH="$IBUS_COMPONENT_PATH" ibus restart
```

Warnings about unrelated engines such as Anthy, libpinyin or typing-booster are produced while IBus scans all components. They do not indicate an OpenBangla failure if OpenBangla appears in ibus list-engine.

## GUI reports a missing shared library

The installer bundles Qt and required runtime libraries under ~/.local/lib/openbangla. The installed launcher exports that directory through LD_LIBRARY_PATH so dynamically loaded modules can also be found.

Re-run bash tools/install.sh after changing runtime-bundling code.

## Clean rebuild

Remove the cached build directory and run the installer again.
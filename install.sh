#!/bin/sh

LEGACY_INSTALL_DIR="/opt/lenovo_fix"
INSTALL_DIR="/opt/throttled"

INIT="$(ps --no-headers -o comm 1)"

if [ "$INIT" = "systemd" ]; then
    systemctl stop lenovo_fix.service >/dev/null 2>&1
    systemctl stop throttled.service >/dev/null 2>&1
elif [ "$INIT" = "runit" ]; then
    sv down lenovo_fix >/dev/null 2>&1
    sv down throttled >/dev/null 2>&1
elif [ "$INIT" = "init" ]; then
    rc-service lenovo_fix stop >/dev/null 2>&1
    rc-service throttled stop >/dev/null 2>&1
fi

mv "$LEGACY_INSTALL_DIR" "$INSTALL_DIR" >/dev/null 2>&1
rm -f "$INSTALL_DIR/lenovo_fix.py" >/dev/null 2>&1
mkdir -p "$INSTALL_DIR" >/dev/null 2>&1
set -e

cd "$(dirname "$0")"

if [ -f /etc/lenovo_fix.conf ]; then
    echo "Updating config filename"
    mv /etc/lenovo_fix.conf /etc/throttled.conf
fi
echo "Copying config file"
if [ ! -f /etc/throttled.conf ]; then
	cp etc/throttled.conf /etc
else
	echo "Config file already exists, skipping"
fi

if [ "$INIT" = "systemd" ]; then
    echo "Copying systemd service file"
    cp systemd/throttled.service /etc/systemd/system
    rm -f /etc/systemd/system/lenovo_fix.service >/dev/null 2>&1
elif [ "$INIT" = "runit" ]; then
    echo "Copying runit service file"
    cp -R runit/throttled /etc/sv/
    rm -r /etc/sv/lenovo_fix >/dev/null 2>&1
elif [ "$INIT" = "init" ]; then
    echo "Copying OpenRC service file"
    cp -R openrc/throttled /etc/init.d/throttled
    rm -f /etc/init.d/lenovo_fix >/dev/null 2>&1
    chmod 755 /etc/init.d/throttled
fi

echo "Copying core files"
cp requirements.txt throttled.py mmio.py "$INSTALL_DIR"
echo "Building virtualenv"
cd "$INSTALL_DIR"
/usr/bin/python3 -m venv venv
. venv/bin/activate
python3 -m pip install wheel
python3 -m pip install -r requirements.txt

if [ "$INIT" = "systemd" ]; then
    echo "Enabling and starting systemd service"
    systemctl daemon-reload
    systemctl enable throttled.service
    systemctl restart throttled.service
elif [ "$INIT" = "runit" ]; then
    echo "Enabling and starting runit service"
    ln -sv /etc/sv/throttled /var/service/
    sv up throttled
elif [ "$INIT" = "init" ]; then
    echo "Enabling and starting OpenRC service"
    rc-update add throttled default
    rc-service throttled start
fi

echo "All done."

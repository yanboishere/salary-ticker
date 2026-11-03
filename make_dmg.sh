#!/bin/zsh
set -e
cd "$(dirname "$0")"
./build.sh
STAGE=$(mktemp -d)
cp -R SalaryTicker.app "$STAGE/工资计时器.app"
ln -s /Applications "$STAGE/Applications"
rm -f SalaryTicker.dmg
hdiutil create -volname "工资计时器" -srcfolder "$STAGE" -ov -format UDZO SalaryTicker.dmg
rm -rf "$STAGE"
echo "DMG: $PWD/SalaryTicker.dmg"

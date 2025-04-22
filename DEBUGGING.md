# PLACEHOLDER

Debugging instructions will move here.

# Clang static analyzer

WIP :)

https://interrupt.memfault.com/blog/static-analysis-with-codechecker

Fixes required for bear:

make clean ; bear intercept --force-wrapper -- make VERBOSE=1 ENABLE_DEBUG_MONITOR=1 -j$(sysctl -n hw.ncpu) AXIS=5 PAXIS=3 CNC=1 VERSION=hagus-`date +%Y-%m-%d-%H-%M-%S` all

> ls -l /opt/homebrew/Cellar/bear/3.1.6/lib/bear/wrapper.d/ | grep -i arm
lrwxr-xr-x@ 1 lburton  admin  10 Apr 19 17:27 arm-none-eabi-ar -> ../wrapper
lrwxr-xr-x@ 1 lburton  admin  10 Apr 19 17:26 arm-none-eabi-g++ -> ../wrapper
lrwxr-xr-x@ 1 lburton  admin  10 Apr 19 17:27 arm-none-eabi-gcc -> ../wrapper

bear citnames --verbose --run-checks --config bear.json

rm -rf .analyzer && analyze-build -o .analyzer

python3 $(which scan-view) .analyzer/*


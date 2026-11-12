#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build
xcrun swiftc -module-cache-path .build/ModuleCache Sources/LEDProbe/main.swift -o .build/LEDProbe -framework IOKit -framework CoreGraphics
exec .build/LEDProbe "$@"

#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build/checks
swiftc Sources/MenuDot/VisibilityRules.swift Tests/MenuDotTests/VisibilityRulesTests.swift -o .build/checks/VisibilityRulesTests
.build/checks/VisibilityRulesTests

#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .build/checks
swiftc Sources/Bartender/VisibilityRules.swift Tests/BartenderTests/VisibilityRulesTests.swift -o .build/checks/VisibilityRulesTests
.build/checks/VisibilityRulesTests

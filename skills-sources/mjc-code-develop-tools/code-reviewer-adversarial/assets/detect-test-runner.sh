#!/usr/bin/env bash
# Detect the project's test runner command by inspecting manifest files.
# Prints the detected command to stdout, or an empty line if unknown.
# Exit code is always 0; the caller decides how to handle empty output.

set -euo pipefail

root="${1:-$PWD}"

if [ ! -d "$root" ]; then
  echo ""
  exit 0
fi

cd "$root"

# Node.js — pnpm > yarn > npm based on lockfile presence
if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then
    echo "pnpm test"
  elif [ -f yarn.lock ]; then
    echo "yarn test"
  elif [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then
    echo "npm test"
  else
    echo "npm test"
  fi
  exit 0
fi

# Python — pytest is the dominant choice; fall back to unittest discover
if [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ] || [ -f tox.ini ]; then
  echo "pytest"
  exit 0
fi
if [ -f setup.py ]; then
  echo "python -m unittest discover"
  exit 0
fi

# Go
if [ -f go.mod ]; then
  echo "go test ./..."
  exit 0
fi

# Rust
if [ -f Cargo.toml ]; then
  echo "cargo test"
  exit 0
fi

# JVM
if [ -f build.gradle ] || [ -f build.gradle.kts ] || [ -f settings.gradle ] || [ -f settings.gradle.kts ]; then
  if [ -x ./gradlew ]; then
    echo "./gradlew test"
  else
    echo "gradle test"
  fi
  exit 0
fi
if [ -f pom.xml ]; then
  echo "mvn test"
  exit 0
fi

# Ruby
if [ -f Gemfile ]; then
  if [ -f Rakefile ]; then
    echo "bundle exec rake test"
  else
    echo "bundle exec rspec"
  fi
  exit 0
fi

# PHP
if [ -f composer.json ]; then
  echo "vendor/bin/phpunit"
  exit 0
fi

# .NET
if ls -1 ./*.sln >/dev/null 2>&1 || ls -1 ./*.csproj >/dev/null 2>&1; then
  echo "dotnet test"
  exit 0
fi

# Elixir
if [ -f mix.exs ]; then
  echo "mix test"
  exit 0
fi

# Unknown
echo ""

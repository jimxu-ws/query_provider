#!/bin/bash

# Test coverage script for Query Provider library
set -e

echo "🧪 Running tests with coverage..."

# Clean previous coverage
rm -rf coverage/
mkdir -p coverage/

# Run tests with coverage
flutter test --coverage

# Generate HTML coverage report
if command -v genhtml &> /dev/null; then
    echo "📊 Generating HTML coverage report..."
    genhtml coverage/lcov.info -o coverage/html
    echo "✅ Coverage report generated at coverage/html/index.html"
else
    echo "⚠️  genhtml not found. Install lcov to generate HTML reports:"
    echo "   macOS: brew install lcov"
    echo "   Ubuntu: sudo apt-get install lcov"
fi

# Display coverage summary
if command -v lcov &> /dev/null; then
    echo "📈 Coverage Summary:"
    lcov --summary coverage/lcov.info
else
    echo "⚠️  lcov not found for coverage summary"
fi

echo "✅ Test coverage complete!"

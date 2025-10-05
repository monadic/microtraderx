#!/bin/bash

echo "=========================================="
echo "MicroTraderX Visual Documentation Preview"
echo "=========================================="
echo ""

echo "📊 ARCHITECTURE.md - Table of Contents:"
echo "----------------------------------------"
grep "^## " /Users/alexis/microtraderx/ARCHITECTURE.md | head -10
echo ""

echo "📈 VISUAL-GUIDE.md - Stage Overview:"
echo "----------------------------------------"
grep "^## Stage" /Users/alexis/microtraderx/VISUAL-GUIDE.md
echo ""

echo "🗺️ DOCS-MAP.md - Reading Paths:"
echo "----------------------------------------"
grep "^### " /Users/alexis/microtraderx/DOCS-MAP.md | head -10
echo ""

echo "📝 File Statistics:"
echo "----------------------------------------"
echo "ARCHITECTURE.md:  $(wc -l < /Users/alexis/microtraderx/ARCHITECTURE.md) lines (35 KB)"
echo "VISUAL-GUIDE.md:  $(wc -l < /Users/alexis/microtraderx/VISUAL-GUIDE.md) lines (48 KB)"
echo "DOCS-MAP.md:      $(wc -l < /Users/alexis/microtraderx/DOCS-MAP.md) lines (10 KB)"
echo "README.md:        $(wc -l < /Users/alexis/microtraderx/README.md) lines (11 KB)"
echo ""
echo "Total: 1911 lines of visual documentation"
echo ""

echo "🎯 Quick Start:"
echo "----------------------------------------"
echo "1. New learner?    Start with README.md (10 min)"
echo "2. See diagrams?   Read VISUAL-GUIDE.md (15 min)"
echo "3. Architecture?   Study ARCHITECTURE.md (20 min)"
echo "4. Not sure?       Check DOCS-MAP.md for your role"
echo ""

echo "✅ All documentation files created successfully!"

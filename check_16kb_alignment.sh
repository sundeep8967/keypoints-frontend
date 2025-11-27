#!/bin/bash

# 16 KB Page Size Alignment Checker
# Based on Android Developer Documentation

APK_FILE="$1"

if [ -z "$APK_FILE" ]; then
    echo "Usage: $0 <path_to_apk>"
    echo "Example: $0 build/app/outputs/flutter-apk/app-release.apk"
    exit 1
fi

if [ ! -f "$APK_FILE" ]; then
    echo "Error: APK file not found: $APK_FILE"
    exit 1
fi

echo "🔍 Checking 16 KB page size alignment for: $APK_FILE"
echo "=================================================="

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "📂 Extracting APK to: $TEMP_DIR"

# Extract APK
unzip -q "$APK_FILE" -d "$TEMP_DIR"

# Check if lib directory exists
if [ ! -d "$TEMP_DIR/lib" ]; then
    echo "✅ No native libraries found - app is compatible with 16 KB page sizes"
    rm -rf "$TEMP_DIR"
    exit 0
fi

echo "🔍 Found native libraries, checking alignment..."

# Check each .so file
UNALIGNED_COUNT=0
TOTAL_COUNT=0

for arch_dir in "$TEMP_DIR/lib"/*; do
    if [ -d "$arch_dir" ]; then
        arch=$(basename "$arch_dir")
        echo ""
        echo "📱 Checking architecture: $arch"
        echo "----------------------------------------"
        
        for so_file in "$arch_dir"/*.so; do
            if [ -f "$so_file" ]; then
                TOTAL_COUNT=$((TOTAL_COUNT + 1))
                filename=$(basename "$so_file")
                
                # Check ELF alignment using objdump if available
                if command -v objdump >/dev/null 2>&1; then
                    alignment_check=$(objdump -p "$so_file" 2>/dev/null | grep "LOAD.*align" | awk '{print $NF}')
                    
                    is_aligned=true
                    for align in $alignment_check; do
                        # Convert hex to decimal for comparison
                        if [[ "$align" =~ ^2\*\*([0-9]+)$ ]]; then
                            power=${BASH_REMATCH[1]}
                            if [ "$power" -lt 14 ]; then  # 2**14 = 16384 (16KB)
                                is_aligned=false
                                break
                            fi
                        fi
                    done
                    
                    if [ "$is_aligned" = true ]; then
                        echo "  ✅ $filename - ALIGNED"
                    else
                        echo "  ❌ $filename - UNALIGNED (needs 16 KB alignment)"
                        UNALIGNED_COUNT=$((UNALIGNED_COUNT + 1))
                    fi
                else
                    echo "  ⚠️  $filename - Cannot check (objdump not available)"
                fi
            fi
        done
    fi
done

echo ""
echo "=================================================="
echo "📊 SUMMARY:"
echo "  Total libraries checked: $TOTAL_COUNT"
echo "  Unaligned libraries: $UNALIGNED_COUNT"

if [ "$UNALIGNED_COUNT" -eq 0 ]; then
    echo "  ✅ All libraries are 16 KB aligned!"
    echo "  🎉 Your app is compatible with 16 KB page size devices"
else
    echo "  ❌ $UNALIGNED_COUNT libraries need 16 KB alignment"
    echo "  🔧 Please rebuild your app with updated build configuration"
fi

# Cleanup
rm -rf "$TEMP_DIR"

exit $UNALIGNED_COUNT
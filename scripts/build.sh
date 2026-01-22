#!/bin/bash
#
# Build script for Simple TFTP Daemon
# Supports building Production, Enterprise, and Datacenter versions
#
# Usage:
#   ./scripts/build.sh [version] [options]
#
# Versions:
#   production  - Build Production version (Apache 2.0)
#   enterprise  - Build Enterprise version (BSL 1.1)
#   datacenter  - Build Datacenter version (BSL 1.1)
#
# Options:
#   --clean     - Clean build directory before building
#   --install   - Install after building
#   --test      - Run tests after building
#   --release   - Build in release mode (default: debug)
#   --help      - Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BUILD_TYPE="Debug"
VERSION=""
CLEAN=false
INSTALL=false
TEST=false

# Default version
DEFAULT_VERSION="production"

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
Build script for Simple TFTP Daemon

Usage:
    $0 [version] [options]

Versions:
    production      Build Production version (Apache 2.0) [default]
    enterprise      Build Enterprise version (BSL 1.1)
    datacenter      Build Datacenter version (BSL 1.1)

Options:
    --clean         Clean build directory before building
    --install       Install after building
    --test          Run tests after building
    --release       Build in release mode (default: debug)
    --help          Show this help message

Examples:
    $0                          # Build production version (debug)
    $0 production --release     # Build production version (release)
    $0 enterprise --clean       # Clean and build enterprise version
    $0 datacenter --install     # Build and install datacenter version
    $0 production --test        # Build and test production version

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            production|enterprise|datacenter)
                VERSION="$1"
                shift
                ;;
            --clean)
                CLEAN=true
                shift
                ;;
            --install)
                INSTALL=true
                shift
                ;;
            --test)
                TEST=true
                shift
                ;;
            --release)
                BUILD_TYPE="Release"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Set default version if not specified
    if [ -z "$VERSION" ]; then
        VERSION="$DEFAULT_VERSION"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check for CMake
    if ! command -v cmake &> /dev/null; then
        print_error "CMake is not installed. Please install CMake 3.16 or later."
        exit 1
    fi

    # Check CMake version
    CMAKE_VERSION=$(cmake --version | head -n1 | cut -d' ' -f3)
    CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d'.' -f1)
    CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d'.' -f2)

    if [ "$CMAKE_MAJOR" -lt 3 ] || ([ "$CMAKE_MAJOR" -eq 3 ] && [ "$CMAKE_MINOR" -lt 16 ]); then
        print_error "CMake 3.16 or later is required. Found: $CMAKE_VERSION"
        exit 1
    fi

    # Check for C++ compiler
    if ! command -v g++ &> /dev/null && ! command -v clang++ &> /dev/null; then
        print_error "C++ compiler (g++ or clang++) is not installed."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Clean build directory
clean_build() {
    if [ "$CLEAN" = true ]; then
        print_info "Cleaning build directory..."
        if [ -d "$BUILD_DIR" ]; then
            rm -rf "$BUILD_DIR"
            print_success "Build directory cleaned"
        else
            print_warning "Build directory does not exist"
        fi
    fi
}

# Configure CMake
configure_cmake() {
    print_info "Configuring CMake for $VERSION version ($BUILD_TYPE mode)..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    cmake "$PROJECT_DIR" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DBUILD_VERSION="$VERSION" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

    if [ $? -eq 0 ]; then
        print_success "CMake configuration completed"
    else
        print_error "CMake configuration failed"
        exit 1
    fi
}

# Build
build() {
    print_info "Building $VERSION version..."

    cd "$BUILD_DIR"
    cmake --build . --config "$BUILD_TYPE" -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

    if [ $? -eq 0 ]; then
        print_success "Build completed successfully"
        
        # Show binary location
        BINARY="$BUILD_DIR/simple-tftpd"
        if [ -f "$BINARY" ]; then
            print_info "Binary location: $BINARY"
            ls -lh "$BINARY"
        fi
    else
        print_error "Build failed"
        exit 1
    fi
}

# Install
install_binary() {
    if [ "$INSTALL" = true ]; then
        print_info "Installing $VERSION version..."

        cd "$BUILD_DIR"
        cmake --install . --config "$BUILD_TYPE"

        if [ $? -eq 0 ]; then
            print_success "Installation completed"
        else
            print_error "Installation failed"
            exit 1
        fi
    fi
}

# Run tests
run_tests() {
    if [ "$TEST" = true ]; then
        print_info "Running tests..."

        cd "$BUILD_DIR"
        if [ -f "CTestTestfile.cmake" ]; then
            ctest --output-on-failure -C "$BUILD_TYPE"
            if [ $? -eq 0 ]; then
                print_success "All tests passed"
            else
                print_warning "Some tests failed"
            fi
        else
            print_warning "No tests found. Build with -DENABLE_TESTS=ON to enable tests."
        fi
    fi
}

# Show build summary
show_summary() {
    echo ""
    print_info "Build Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Version:        $VERSION"
    echo "  Build Type:     $BUILD_TYPE"
    echo "  Build Directory: $BUILD_DIR"
    echo "  Binary:         $BUILD_DIR/simple-tftpd"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ -f "$BUILD_DIR/simple-tftpd" ]; then
        print_success "Build completed successfully!"
        echo ""
        print_info "To run the daemon:"
        echo "  $BUILD_DIR/simple-tftpd --help"
    fi
}

# Main function
main() {
    print_info "Simple TFTP Daemon Build Script"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    parse_args "$@"
    check_prerequisites
    clean_build
    configure_cmake
    build
    install_binary
    run_tests
    show_summary
}

# Run main function
main "$@"

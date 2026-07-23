herdr_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$herdr_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <herdr_version> <build_version> [architecture]"
    echo "Example: $0 0.7.5 1 arm64"
    echo "Example: $0 0.7.5 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

# Function to map Debian architecture to herdr release asset name
get_herdr_asset() {
    local arch=$1
    case "$arch" in
        "amd64")
            echo "herdr-linux-x86_64"
            ;;
        "arm64")
            echo "herdr-linux-aarch64"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1
    local herdr_asset

    herdr_asset=$(get_herdr_asset "$build_arch")
    if [ -z "$herdr_asset" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    echo "Building for architecture: $build_arch using $herdr_asset"

    # Clean up any previous builds for this architecture
    rm -rf "$herdr_asset" || true

    # Download herdr binary for this architecture (upstream ships a raw binary,
    # not a tarball). Place it inside a directory named after the asset so the
    # Dockerfile can COPY it as /usr/bin/herdr.
    mkdir -p "$herdr_asset"
    if ! wget "https://github.com/ogulcancelik/herdr/releases/download/v${herdr_VERSION}/${herdr_asset}" -O "$herdr_asset/herdr"; then
        echo "❌ Failed to download herdr binary for $build_arch"
        rm -rf "$herdr_asset" || true
        return 1
    fi
    chmod 755 "$herdr_asset/herdr"

    # herdr provides amd64/arm64 static binaries that run on all supported dists.
    declare -a arr=("bookworm" "trixie" "forky" "sid")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$herdr_VERSION-${BUILD_VERSION}~${dist}_${build_arch}"
        echo "  Building $FULL_VERSION"

        if ! docker build . -t "herdr-$dist-$build_arch" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg herdr_VERSION="$herdr_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg HERDR_ASSET="$herdr_asset"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "herdr-$dist-$build_arch")"
        if ! docker cp "$id:/herdr_$FULL_VERSION.deb" - > "./herdr_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./herdr_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    # Clean up extracted directory
    rm -rf "$herdr_asset" || true

    echo "✅ Successfully built for $build_arch"
    return 0
}

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building herdr $herdr_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    # All supported architectures
    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la herdr_*.deb
else
    # Build for single architecture
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi

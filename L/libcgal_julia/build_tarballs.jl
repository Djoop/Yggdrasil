# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder
import Pkg: PackageSpec

name = "libcgal_julia"
version = v"0.15"

isyggdrasil = get(ENV, "YGGDRASIL", "") == "true"
rname = "libcgal-julia"

# Collection of sources required to build CGAL
sources = [
    isyggdrasil ?
        GitSource("https://github.com/rgcv/$rname.git",
                  "64587dbe445f3c6f7bff5ffd67e367e4131c7300") :
        DirectorySource(joinpath(ENV["HOME"], "src/github/rgcv/$rname"))
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency(PackageSpec(name="Julia_jll", version="v1.4.1")),

    Dependency("CGAL_jll"),
    Dependency("libcxxwrap_julia_jll"),
]

# Bash recipe for building across all platforms
jlcgaldir = ifelse(isyggdrasil, rname, ".")
script = raw"""
## pre-build setup
# exit on error
set -eu

macosflags=
case $target in
  *apple-darwin*)
    macosflags="-DCMAKE_CXX_COMPILER_ID=AppleClang"
    macosflags="$macosflags -DCMAKE_CXX_COMPILER_VERSION=10.0.0"
    macosflags="$macosflags -DCMAKE_CXX_STANDARD_COMPUTED_DEFAULT=11"
    ;;
esac
""" * """
## configure build
cmake $jlcgaldir -B /tmp/build """ * raw"""\
  `# cmake specific` \
  -DCMAKE_TOOLCHAIN_FILE=$CMAKE_TARGET_TOOLCHAIN \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_FIND_ROOT_PATH=$prefix \
  -DCMAKE_INSTALL_PREFIX=$prefix \
  $macosflags \
  `# tell jlcxx where julia is` \
  -DJulia_PREFIX=$prefix

## and away we go..
VERBOSE=ON cmake --build /tmp/build --config Release --target install -- -j$nproc
""" * """
install_license $jlcgaldir/LICENSE
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "freebsd"; cxxstring_abi = "cxx11"),
    Platform("aarch64", "linux"; libc="glibc", cxxstring_abi = "cxx11"),
    # generates plentiful warnings about parameter passing ABI changes, better
    # safe than sorry
    # Platform("armv7l", "linux"; libc="glibc", cxxstring_abi = "cxx11"),
    Platform("i686", "linux"; libc="glibc", cxxstring_abi = "cxx11"),
    Platform("x86_64", "linux"; libc="glibc", cxxstring_abi = "cxx11"),
    Platform("x86_64", "macos"; cxxstring_abi = "cxx11"),
    Platform("i686", "windows"; cxxstring_abi = "cxx11"),
    Platform("x86_64", "windows"; cxxstring_abi = "cxx11"),
]

# The products that we will ensure are always built
products = [
    LibraryProduct("libcgal_julia_exact", :libcgal_julia_exact),
    LibraryProduct("libcgal_julia_inexact", :libcgal_julia_inexact),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; preferred_gcc_version=v"7")

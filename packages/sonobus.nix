{ sonobus }:

# Upstream 1.7.2 uses C++17 aggregate initialization in VersionInfo. GCC 16
# defaults to C++20, where its explicitly defaulted constructor is no longer
# an aggregate. Keep the upstream language level, not an old compiler/input.
sonobus.overrideAttrs (old: {
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_CXX_STANDARD=17" ];
})

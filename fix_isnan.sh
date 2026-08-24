#!/bin/bash
find "$1" -name "ff_ffplay.c" -exec sh -c '
for f; do
  awk '\''
    /^\/\/ FIXME: 9 work around NDKr8e/ { skip = 1; print "// isnan hack removed"; next }
    skip == 1 && /^\#if defined\(__ANDROID__\)/ { skip = 2; next }
    skip == 2 && /^\#ifdef isnan/ { skip = 3; next }
    skip == 3 && /^\#undef isnan/ { skip = 4; next }
    skip == 4 && /^\#define isnan/ { skip = 5; next }
    (skip == 4 || skip == 5) && /^\#endif/ { skip = 6; next }
    skip == 6 && /^\#endif/ { skip = 0; next }
    skip > 0 { next }
    { print }
  '\'' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
' sh {} +

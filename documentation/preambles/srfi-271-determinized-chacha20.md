## Overview

The ChaCha20 implementation behind `(srfi 271 determinized)`, under the name
the SRFI suggests for algorithm-specific libraries. A port delivers the
ChaCha20 keystream (20 rounds, all-zero nonce) of a 256-bit key; for the first
2^32 blocks it equals RFC 8439 ChaCha20 with an all-zero nonce. Its state is
the vector `#(chacha20 key counter offset)`: the 32-byte key, the keystream
block and the byte within that block that will be read next.

# Port Example Omissions

Examples in the Python reference SDK that this Ruby port deliberately
does NOT mirror. Each entry is a Python example file; the rationale
explains why the port omits the equivalent.

Format:
- `<python-stem>`: <one-sentence rationale>

The `audit_example_parity.py` script reads this file from the port root
and excludes the listed stems from its missing-example diff.

## Search-related (no search functionality in this port)

The Python SDK's search subsystem (FAISS / pgvector / sigmond / native
local vector search) is not ported to Ruby — see PORT_OMISSIONS.md for
the symbol-level rationale. Examples that demonstrate search-only
features are therefore omitted here as well.

- `local_search_agent`: depends on the local-vector-search subsystem
  (FAISS via Python wheels) which has no Ruby equivalent. The
  `native_vector_search` skill in this port documents the gap and
  raises a clear error if instantiated.

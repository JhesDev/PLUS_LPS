/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_MAP_STYLE_URL?: string
  readonly VITE_MAP_TILES_URL?: string
  readonly VITE_MAP_ATTRIBUTION?: string
  readonly VITE_MAP_GLYPHS_URL?: string
  readonly VITE_API_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

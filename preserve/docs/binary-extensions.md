# Binary & Native Extension Reference

## UNREADABLE — Do NOT attempt to read these files

### Executables & Libraries
`.exe` `.dll` `.so` `.dylib` `.obj` `.o` `.a` `.lib` `.bin` `.com` `.sys` `.msi` `.app`

### Archives & Compressed
`.zip` `.tar` `.gz` `.tgz` `.bz2` `.7z` `.rar` `.xz` `.cab` `.iso` `.dmg` `.pkg` `.deb` `.rpm`

### Media — Audio
`.mp3` `.wav` `.flac` `.ogg` `.aac` `.wma` `.m4a` `.opus` `.mid` `.midi`

### Media — Video
`.mp4` `.avi` `.mov` `.mkv` `.wmv` `.flv` `.webm` `.m4v` `.3gp` `.ts`

### Media — Images (binary raster, not natively supported)
`.ico` `.cur` `.xcf` `.psd` `.psb` `.raw` `.cr2` `.nef` `.arw` `.dng`

### Design & Creative
`.ai` `.sketch` `.fig` `.xd` `.indd` `.eps` `.svgz`

### Office Documents (zipped XML — not plain text)
`.docx` `.xlsx` `.pptx` `.doc` `.xls` `.ppt` `.odt` `.ods` `.odp` `.pages` `.numbers` `.key`

### Database & Storage
`.db` `.sqlite` `.sqlite3` `.mdb` `.accdb` `.frm` `.ibd` `.myd`

### Compiled / Bytecode
`.pyc` `.pyo` `.class` `.wasm` `.beam` `.luac` `.elc`

### ML / Data Science
`.pkl` `.pickle` `.npy` `.npz` `.h5` `.hdf5` `.model` `.weights` `.onnx` `.pb` `.pt` `.pth` `.joblib` `.safetensors`

### Fonts
`.ttf` `.otf` `.woff` `.woff2` `.eot`

### Certificates & Keys (binary forms)
`.p12` `.pfx` `.der` `.cer` `.crt` `.keystore`

---

## NATIVE — Claude reads these natively (vision / PDF pipeline)

### PDFs
`.pdf`

### Images (natively supported)
`.jpg` `.jpeg` `.png` `.webp` `.gif` `.bmp` `.tiff` `.tif`

---

## TEXT — Everything else is treated as plain text

Includes but not limited to:
`.txt` `.md` `.rst` `.adoc` `.csv` `.tsv` `.json` `.jsonl` `.yaml` `.yml` `.toml` `.ini` `.cfg` `.conf` `.env` `.properties`
`.js` `.ts` `.jsx` `.tsx` `.mjs` `.cjs` `.vue` `.svelte`
`.py` `.rb` `.php` `.java` `.kt` `.swift` `.go` `.rs` `.c` `.cpp` `.h` `.hpp` `.cs` `.scala` `.clj` `.ex` `.exs` `.erl` `.hs` `.ml` `.fs` `.lua` `.r` `.jl` `.dart` `.nim` `.zig`
`.sh` `.bash` `.zsh` `.fish` `.ps1` `.bat` `.cmd`
`.html` `.htm` `.css` `.scss` `.sass` `.less` `.xml` `.svg`
`.sql` `.graphql` `.proto` `.thrift` `.avsc`
`.tf` `.hcl` `.dockerfile` `Dockerfile` `.dockerignore` `.gitignore` `.gitattributes`
`.lock` (but these are auto-skipped as low-value)

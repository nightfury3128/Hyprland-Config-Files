# file-convert

Local file conversion for Dolphin (KDE Plasma 6). One Bash CLI, four KDE
service-menu `.desktop` files. Everything runs on your machine — no uploads.

## Layout

```
tools/file-convert/
├── bin/file-convert                # the CLI (Bash)
├── servicemenus/
│   ├── file-convert-office.desktop
│   ├── file-convert-images.desktop
│   ├── file-convert-av.desktop
│   └── file-convert-pdf.desktop
├── install.sh                      # symlinks to ~/.local/{bin,share/kio/servicemenus}
├── packages.txt                    # Arch deps (core + optional)
└── README.md
```

## Install

```bash
# 1. Install deps (see packages.txt for the split).
sudo pacman -S --needed libreoffice-fresh imagemagick ffmpeg ghostscript qpdf \
                        poppler libnotify pandoc
# Optional:
sudo pacman -S --needed ocrmypdf libheif libavif

# 2. Deploy CLI + service menus (symlinks, idempotent).
~/dotfiles/tools/file-convert/install.sh

# 3. Reload Dolphin so it picks up the new menus.
kbuildsycoca6 --noincremental
kquitapp6 dolphin 2>/dev/null; setsid dolphin >/dev/null 2>&1 &

# 4. Sanity check.
file-convert doctor
```

Add `$HOME/.local/bin` to `PATH` if not already present.

## Operations

Run `file-convert list` for the full menu. Highlights:

| Category | Operation | Notes |
|---|---|---|
| Office | `office-to-pdf`, `doc-to-pdf`, `presentation-to-pdf`, `spreadsheet-to-pdf` | LibreOffice headless |
| Office | `odt-to-docx`, `docx-to-odt`, `odp-to-pptx`, `pptx-to-odp`, `ods-to-xlsx`, `xlsx-to-ods` | |
| Office | `pdf-to-docx` | **Lossy** text extraction (pdftotext → pandoc). Output suffixed `-extracted.docx`. |
| Image | `image-to-png/jpg/webp/avif/pdf` | JPEG flattens alpha; `-auto-orient` preserved |
| Image | `compress-image`, `resize-image-50` | Never touches original |
| Audio | `audio-to-mp3` (VBR q2), `-flac`, `-opus` (128k), `-wav`, `extract-audio` (m4a copy) | |
| Video | `video-to-mp4` (H.264/AAC, +faststart), `-webm` (VP9/Opus), `-mkv`, `-gif`, `compress-video` | |
| PDF | `compress-pdf` (gs `/ebook`), `ocr-pdf`, `merge-pdf`, `split-pdf-pages`, `extract-pdf-images` | |
| PDF | `rotate-pdf-right/left`, `pdf-to-png` (200 DPI), `images-to-pdf` | |

Meta: `file-convert list`, `file-convert doctor`, `file-convert --dry-run <op> ...`.

## Output naming

Placed beside the source. Never overwrites — collisions become
`name-1.ext`, `name-2.ext`. Multi-dot names preserved
(`report.final.v2.docx → report.final.v2.pdf`). Special suffixes:
`-compressed`, `-ocr`, `-50pct`, `-extracted`, `-rot-right`, `-rot-left`.
Multi-file outputs go into `stem-pages/`, `stem-png/`, `stem-images/` or a
timestamped `merged-YYYYMMDD-HHMMSS.pdf` / `images-YYYYMMDD-HHMMSS.pdf` in
the first file's directory.

## Notifications & logs

`notify-send` fires at start and end (or on failure). Detailed backend stderr
goes to `$XDG_STATE_HOME/file-convert/last-run.log` (default
`~/.local/state/file-convert/last-run.log`), truncated per run.

## Limitations

- **PDF → DOCX**: only text is recovered. Layout, tables, images are lost.
  The file is deliberately named `*-extracted.docx` and the notification
  says "lossy".
- **HEIC/AVIF input** needs `libheif` / `libavif` for ImageMagick.
- **H.264/AAC** assumes software encoders. Hardware (NVENC/VAAPI) is not
  auto-selected — if you want it, edit `op_video_to_mp4` in the CLI.
- **OCR language** defaults to English. Override with
  `OCR_LANGUAGES=eng+deu file-convert ocr-pdf ...` (set inside your shell)
  or pass `-l` via a small edit to `op_ocr_pdf`.

## Adding a new operation

1. Add `op_<name>() { ... }` in `bin/file-convert`. Use `need <cmds>`,
   `unique_path`, `run`, and place output beside `$src`.
2. Register it in `do_list`.
3. Add a `[Desktop Action X]` entry in the appropriate
   `servicemenus/*.desktop`, add its ID to that file's `Actions=` list, and
   restrict `MimeType=` sensibly.
4. `kbuildsycoca6 --noincremental` and restart Dolphin.

## Testing without Dolphin

```bash
bash -n bin/file-convert                         # syntax
shellcheck bin/file-convert                      # if installed
desktop-file-validate servicemenus/*.desktop     # if installed
file-convert --dry-run image-to-png ~/pic.png    # show plan, no writes
file-convert doctor                              # dep + install status
```

## Reload Dolphin service menus

```bash
kbuildsycoca6 --noincremental
kquitapp6 dolphin 2>/dev/null; setsid dolphin >/dev/null 2>&1 &
```

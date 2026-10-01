// ============================================================
// FileWorks — File Tools (ZIP/Rename using JSZip)
// ============================================================

const FileToolsLib = {
  // ---- Security: Validate ZIP entry path ----
  _validateZipPath(entryName) {
    // Protect against ZIP Slip / path traversal
    const normalized = entryName.replace(/\\/g, '/');
    if (normalized.startsWith('/') || normalized.startsWith('..')) {
      throw new Error(`Security: Unsafe path in ZIP entry: "${entryName}"`);
    }
    const parts = normalized.split('/');
    if (parts.some(p => p === '..')) {
      throw new Error(`Security: Path traversal detected in ZIP entry: "${entryName}"`);
    }
    // Check for Windows absolute paths (C:\, D:\, etc.)
    if (/^[A-Za-z]:/.test(normalized)) {
      throw new Error(`Security: Absolute Windows path in ZIP entry: "${entryName}"`);
    }
    return normalized;
  },

  // ---- Create ZIP ----
  async createZip(files, zipName = 'archive.zip') {
    const zip = new JSZip();
    for (const file of files) {
      const safeName = FW.file.sanitizeName(file.name);
      zip.file(safeName, file);
    }
    const blob = await zip.generateAsync({
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 },
    });
    return { blob, name: zipName.endsWith('.zip') ? zipName : zipName + '.zip' };
  },

  // ---- Extract ZIP ----
  async extractZip(file) {
    const arrayBuffer = await FW.file.readAsArrayBuffer(file);
    let zip;
    try {
      zip = await JSZip.loadAsync(arrayBuffer);
    } catch(e) {
      throw new Error(`Cannot open ZIP archive: ${file.name}. It may be corrupted.`);
    }

    const entries = [];
    for (const [name, entry] of Object.entries(zip.files)) {
      if (entry.dir) continue;
      // Security check
      const safePath = this._validateZipPath(name);
      const content = await entry.async('blob');
      const parts = safePath.split('/');
      const filename = parts[parts.length - 1];
      entries.push({ name: filename, path: safePath, blob: content });
    }
    if (entries.length === 0) throw new Error('The ZIP archive is empty.');
    return entries;
  },

  // ---- Batch Rename (preview) ----
  generateRenamePreview(files, options = {}) {
    const {
      pattern = '{name}',
      startNumber = 1,
      zeroPadding = 3,
      findText = '',
      replaceText = '',
    } = options;

    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const preview = [];

    files.forEach((file, i) => {
      const ext = file.name.includes('.') ? '.' + file.name.split('.').pop() : '';
      const nameWithoutExt = file.name.replace(/\.[^.]+$/, '');
      const num = String(startNumber + i).padStart(zeroPadding, '0');

      let newBase = pattern || nameWithoutExt;
      newBase = newBase.replace(/\{number\}/g, num);
      newBase = newBase.replace(/\{date\}/g, dateStr);
      newBase = newBase.replace(/\{name\}/g, nameWithoutExt);

      if (findText) {
        newBase = newBase.split(findText).join(replaceText);
      }

      const newName = FW.file.sanitizeName(newBase) + ext;
      preview.push({ original: file.name, newName, file });
    });

    return preview;
  },

  // ---- Download all extraced files as ZIP ----
  async downloadExtractedAsZip(entries, zipName = 'extracted.zip') {
    const zip = new JSZip();
    for (const entry of entries) {
      zip.file(entry.path || entry.name, entry.blob);
    }
    const blob = await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' });
    return { blob, name: zipName };
  },
};

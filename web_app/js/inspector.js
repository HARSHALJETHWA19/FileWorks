// ============================================================
// FileWorks — Client-Side File Inspector & Analyzer Module
// Deep technical document inspection running 100% in-browser.
// ============================================================

const FileInspector = {
  /**
   * Deeply inspects a PDF document.
   * Returns page counts, dimensions (pt, mm, in), orientation, rotation, and metadata.
   */
  async inspectPdf(file) {
    if (!window.PDFLib) {
      throw new Error('PDFLib is required to inspect PDF files.');
    }
    const { PDFDocument } = window.PDFLib;
    const arrayBuffer = await FW.file.readAsArrayBuffer(file);
    const pdfDoc = await PDFDocument.load(arrayBuffer, { ignoreEncryption: true });

    const pageCount = pdfDoc.getPageCount();
    const pages = pdfDoc.getPages();
    const pageDetails = [];

    // Standard paper dimension mapping tolerances (in points)
    const matchPaperSize = (w, h) => {
      const sw = Math.min(w, h);
      const sl = Math.max(w, h);
      if (Math.abs(sw - 595.28) < 4 && Math.abs(sl - 841.89) < 4) return 'ISO A4 (210 × 297 mm)';
      if (Math.abs(sw - 612) < 4 && Math.abs(sl - 792) < 4) return 'US Letter (8.5 × 11 in)';
      if (Math.abs(sw - 612) < 4 && Math.abs(sl - 1008) < 4) return 'US Legal (8.5 × 14 in)';
      if (Math.abs(sw - 419.53) < 4 && Math.abs(sl - 595.28) < 4) return 'ISO A5 (148 × 210 mm)';
      if (Math.abs(sw - 841.89) < 4 && Math.abs(sl - 1190.55) < 4) return 'ISO A3 (297 × 420 mm)';
      return 'Custom Dimensions';
    };

    pages.forEach((p, idx) => {
      const { width, height } = p.getSize();
      const rotation = p.getRotation ? p.getRotation().angle : 0;
      const isLandscape = width > height;
      const widthMm = (width * 25.4 / 72).toFixed(1);
      const heightMm = (height * 25.4 / 72).toFixed(1);
      const widthIn = (width / 72).toFixed(2);
      const heightIn = (height / 72).toFixed(2);
      const matched = matchPaperSize(width, height);

      pageDetails.push({
        pageNumber: idx + 1,
        widthPt: Math.round(width * 10) / 10,
        heightPt: Math.round(height * 10) / 10,
        widthMm,
        heightMm,
        widthIn,
        heightIn,
        standardName: matched,
        orientation: isLandscape ? 'Landscape' : 'Portrait',
        rotation: `${rotation}°`,
      });
    });

    const title = pdfDoc.getTitle ? pdfDoc.getTitle() : null;
    const author = pdfDoc.getAuthor ? pdfDoc.getAuthor() : null;
    const producer = pdfDoc.getProducer ? pdfDoc.getProducer() : null;
    const creator = pdfDoc.getCreator ? pdfDoc.getCreator() : null;

    return {
      type: 'pdf',
      name: file.name,
      fileSize: file.size,
      formattedSize: FW.file.formatSize(file.size),
      pageCount,
      pageDetails,
      metadata: {
        title: title || 'Not specified',
        author: author || 'Not specified',
        producer: producer || 'Not specified',
        creator: creator || 'Not specified',
      },
    };
  },

  /**
   * Deeply inspects an Image file.
   * Extracts dimensions, Megapixels, aspect ratio, MIME type.
   */
  async inspectImage(file) {
    const dataUrl = await FW.file.readAsDataURL(file);
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const width = img.naturalWidth;
        const height = img.naturalHeight;
        const totalPixels = width * height;
        const megapixels = (totalPixels / 1000000).toFixed(2);

        // Aspect ratio calculations
        const gcd = (a, b) => b === 0 ? a : gcd(b, a % b);
        const divisor = gcd(width, height);
        const ratioW = width / divisor;
        const ratioH = height / divisor;
        let commonRatio = `${ratioW}:${ratioH}`;
        if (Math.abs(width / height - 16 / 9) < 0.02) commonRatio = '16:9 (Widescreen)';
        else if (Math.abs(width / height - 4 / 3) < 0.02) commonRatio = '4:3 (Standard)';
        else if (Math.abs(width / height - 1) < 0.01) commonRatio = '1:1 (Square)';
        else if (Math.abs(width / height - 3 / 2) < 0.02) commonRatio = '3:2 (Classic 35mm)';

        const ext = (file.name.split('.').pop() || '').toUpperCase();

        resolve({
          type: 'image',
          name: file.name,
          format: ext,
          fileSize: file.size,
          formattedSize: FW.file.formatSize(file.size),
          width,
          height,
          megapixels: `${megapixels} MP`,
          aspectRatio: commonRatio,
          orientation: width >= height ? (width === height ? 'Square' : 'Landscape') : 'Portrait',
        });
      };
      img.onerror = () => reject(new Error(`Failed to decode image "${file.name}".`));
      img.src = dataUrl;
    });
  },

  /**
   * Deeply inspects a ZIP archive.
   */
  async inspectZip(file) {
    if (!window.JSZip) {
      throw new Error('JSZip is required to inspect ZIP archives.');
    }
    const arrayBuffer = await FW.file.readAsArrayBuffer(file);
    const zip = await JSZip.loadAsync(arrayBuffer);

    let fileCount = 0;
    let folderCount = 0;
    let totalUncompressed = 0;
    const entries = [];

    for (const [name, entry] of Object.entries(zip.files)) {
      if (entry.dir) {
        folderCount++;
      } else {
        fileCount++;
        // uncompressed size if available in headers
        const uncompressed = entry._data ? (entry._data.uncompressedSize || 0) : 0;
        totalUncompressed += uncompressed;
        entries.push({
          name,
          size: uncompressed ? FW.file.formatSize(uncompressed) : 'Unknown',
        });
      }
    }

    const compressedSize = file.size;
    let ratioText = 'N/A';
    if (totalUncompressed > 0) {
      const pct = Math.round((1 - (compressedSize / totalUncompressed)) * 100);
      ratioText = `${pct > 0 ? pct + '% reduction' : 'Minimal'}`;
    }

    return {
      type: 'zip',
      name: file.name,
      fileSize: file.size,
      formattedSize: FW.file.formatSize(file.size),
      fileCount,
      folderCount,
      totalUncompressed: totalUncompressed > 0 ? FW.file.formatSize(totalUncompressed) : 'Dynamic stream',
      ratioText,
      entries: entries.slice(0, 30),
      totalEntriesCount: entries.length,
    };
  },

  /**
   * Displays an interactive inspector modal with technical details.
   */
  showModal(details) {
    const existing = document.getElementById('fw-inspector-modal');
    if (existing) existing.remove();

    const overlay = document.createElement('div');
    overlay.id = 'fw-inspector-modal';
    overlay.className = 'modal-overlay fade-in';

    let bodyHtml = '';

    if (details.type === 'pdf') {
      const firstPage = details.pageDetails[0] || {};
      bodyHtml = `
        <div style="margin-bottom:18px;">
          <h4 style="margin:0 0 10px;font-size:1rem;color:var(--color-primary);">Document Properties</h4>
          <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(160px, 1fr));gap:10px;background:var(--color-surface-2);padding:14px;border-radius:var(--radius-md);border:1px solid var(--color-border);font-size:0.875rem;">
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">TOTAL PAGES</strong>${details.pageCount}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">FILE SIZE</strong>${details.formattedSize}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">PAGE 1 SIZE</strong>${firstPage.standardName || 'Custom'}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">ORIENTATION</strong>${firstPage.orientation || 'Portrait'}</div>
          </div>
        </div>

        <div style="margin-bottom:18px;">
          <h4 style="margin:0 0 10px;font-size:1rem;color:var(--color-primary);">Page Geometry Breakdown</h4>
          <div style="max-height:180px;overflow-y:auto;border:1px solid var(--color-border);border-radius:var(--radius-md);">
            <table style="width:100%;font-size:0.8125rem;border-collapse:collapse;text-align:left;">
              <thead style="background:var(--color-surface-2);border-bottom:1px solid var(--color-border);">
                <tr>
                  <th style="padding:8px 10px;">Page</th>
                  <th style="padding:8px 10px;">Standard Format</th>
                  <th style="padding:8px 10px;">Dimensions (mm)</th>
                  <th style="padding:8px 10px;">Points (pt)</th>
                  <th style="padding:8px 10px;">Rotation</th>
                </tr>
              </thead>
              <tbody>
                ${details.pageDetails.map(p => `
                  <tr style="border-bottom:1px solid var(--color-border);">
                    <td style="padding:8px 10px;font-weight:600;">p. ${p.pageNumber}</td>
                    <td style="padding:8px 10px;">${p.standardName}</td>
                    <td style="padding:8px 10px;">${p.widthMm} × ${p.heightMm} mm</td>
                    <td style="padding:8px 10px;">${p.widthPt} × ${p.heightPt}</td>
                    <td style="padding:8px 10px;">${p.rotation}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <div>
          <h4 style="margin:0 0 10px;font-size:1rem;color:var(--color-primary);">Metadata</h4>
          <div style="font-size:0.8125rem;background:var(--color-surface-2);padding:12px;border-radius:var(--radius-md);border:1px solid var(--color-border);line-height:1.6;">
            <div><strong>Title:</strong> ${details.metadata.title}</div>
            <div><strong>Author:</strong> ${details.metadata.author}</div>
            <div><strong>Creator:</strong> ${details.metadata.creator}</div>
            <div><strong>Producer:</strong> ${details.metadata.producer}</div>
          </div>
        </div>
      `;
    } else if (details.type === 'image') {
      bodyHtml = `
        <div style="margin-bottom:18px;">
          <h4 style="margin:0 0 10px;font-size:1rem;color:var(--color-primary);">Image Specifications</h4>
          <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(160px, 1fr));gap:10px;background:var(--color-surface-2);padding:14px;border-radius:var(--radius-md);border:1px solid var(--color-border);font-size:0.875rem;">
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">DIMENSIONS</strong>${details.width} × ${details.height} px</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">RESOLUTION</strong>${details.megapixels}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">ASPECT RATIO</strong>${details.aspectRatio}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">FORMAT</strong>${details.format}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">FILE SIZE</strong>${details.formattedSize}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">LAYOUT</strong>${details.orientation}</div>
          </div>
        </div>
      `;
    } else if (details.type === 'zip') {
      bodyHtml = `
        <div style="margin-bottom:18px;">
          <h4 style="margin:0 0 10px;font-size:1rem;color:var(--color-primary);">Archive Overview</h4>
          <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(160px, 1fr));gap:10px;background:var(--color-surface-2);padding:14px;border-radius:var(--radius-md);border:1px solid var(--color-border);font-size:0.875rem;">
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">FILES ENCLOSED</strong>${details.fileCount}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">FOLDERS</strong>${details.folderCount}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">ARCHIVE SIZE</strong>${details.formattedSize}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">UNCOMPRESSED</strong>${details.totalUncompressed}</div>
            <div><strong style="color:var(--color-text-muted);display:block;font-size:0.75rem;">SAVINGS RATIO</strong>${details.ratioText}</div>
          </div>
        </div>

        <div>
          <h4 style="margin:0 0 10px;font-size:1rem;color:var(--color-primary);">Archive Contents (First ${details.entries.length})</h4>
          <div style="max-height:180px;overflow-y:auto;border:1px solid var(--color-border);border-radius:var(--radius-md);background:var(--color-surface-2);padding:10px;font-size:0.8125rem;">
            ${details.entries.map(e => `
              <div style="display:flex;justify-content:space-between;padding:4px 0;border-bottom:1px solid var(--color-border);">
                <span style="font-family:monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-right:10px;">${e.name}</span>
                <span style="color:var(--color-text-muted);white-space:nowrap;">${e.size}</span>
              </div>
            `).join('')}
          </div>
        </div>
      `;
    }

    overlay.innerHTML = `
      <div class="modal-card" role="dialog" aria-labelledby="inspector-modal-title" style="max-width:620px;">
        <div class="modal-header">
          <div style="display:flex;align-items:center;gap:10px;">
            <span style="font-size:22px;">🔍</span>
            <h3 id="inspector-modal-title" style="margin:0;font-size:1.2rem;">File Inspector: ${details.name}</h3>
          </div>
          <button class="modal-close-btn" id="inspector-modal-close" aria-label="Close">✕</button>
        </div>
        <div class="modal-body" style="padding:16px 0;">
          ${bodyHtml}
        </div>
        <div class="modal-footer" style="display:flex;justify-content:space-between;align-items:center;">
          <span style="font-size:0.75rem;color:var(--color-text-muted);">🔒 Read locally in browser memory</span>
          <button class="btn btn-primary btn-sm" id="inspector-modal-ok">Done</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const close = () => overlay.remove();
    overlay.querySelector('#inspector-modal-close')?.addEventListener('click', close);
    overlay.querySelector('#inspector-modal-ok')?.addEventListener('click', close);
    overlay.addEventListener('click', e => { if (e.target === overlay) close(); });
  },
};

if (typeof window !== 'undefined') {
  window.FileInspector = FileInspector;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FileInspector;
}

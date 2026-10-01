// ============================================================
// FileWorks — Universal Browser Preview Modal
// Handles in-browser preview for PDF, Images, Text, and fallbacks.
// ============================================================

const PreviewModal = {
  _activeBlobUrl: null,

  open(blob, filename = 'document') {
    this.close();

    const ext = (filename.split('.').pop() || '').toLowerCase();
    const type = blob.type || '';
    const isPdf = ext === 'pdf' || type === 'application/pdf';
    const isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg'].includes(ext) || type.startsWith('image/');
    const isText = ['txt', 'csv', 'json', 'xml', 'md', 'log'].includes(ext) || type.startsWith('text/');

    const blobUrl = URL.createObjectURL(blob);
    this._activeBlobUrl = blobUrl;

    const overlay = document.createElement('div');
    overlay.id = 'fw-preview-modal';
    overlay.className = 'preview-overlay fade-in';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', `Preview of ${filename}`);

    let bodyContent = '';

    if (isPdf) {
      bodyContent = `
        <div class="preview-pdf-wrapper">
          <iframe src="${blobUrl}#toolbar=1" class="preview-pdf-frame" title="PDF preview"></iframe>
          <div class="preview-fallback-notice">
            <span>Embedded PDF preview not rendering?</span>
            <a href="${blobUrl}" target="_blank" rel="noopener" class="btn btn-outline btn-sm">Open in New Tab ↗</a>
          </div>
        </div>
      `;
    } else if (isImage) {
      bodyContent = `
        <div class="preview-image-wrapper">
          <img src="${blobUrl}" alt="${filename}" class="preview-image" id="preview-img-el">
        </div>
      `;
    } else if (isText) {
      bodyContent = `
        <div class="preview-text-wrapper">
          <pre class="preview-text-content" id="preview-text-pre">Loading content...</pre>
        </div>
      `;
      // Load text asynchronously
      blob.text().then(text => {
        const pre = document.getElementById('preview-text-pre');
        if (pre) pre.textContent = text.slice(0, 50000); // cap to 50k chars
      }).catch(() => {
        const pre = document.getElementById('preview-text-pre');
        if (pre) pre.textContent = 'Unable to read text preview.';
      });
    } else {
      bodyContent = `
        <div class="preview-unsupported">
          <div style="font-size:48px;margin-bottom:12px;">📁</div>
          <h4 style="margin-bottom:8px;">Preview isn't available for this file type</h4>
          <p style="color:var(--color-text-muted);font-size:.875rem;margin-bottom:20px;">
            This file (${ext ? '.' + ext : 'binary'}) can be downloaded directly to your device.
          </p>
          <button class="btn btn-primary" id="preview-dl-unsupported">⬇ Download File</button>
        </div>
      `;
    }

    overlay.innerHTML = `
      <div class="preview-dialog">
        <div class="preview-header">
          <div class="preview-title-group">
            <span class="preview-title-icon">${isPdf ? '📄' : isImage ? '🖼️' : '📎'}</span>
            <span class="preview-title-text" title="${filename}">${filename}</span>
            <span class="preview-size-badge">${FW.file.formatSize(blob.size)}</span>
          </div>
          <div class="preview-actions">
            <a href="${blobUrl}" download="${filename}" class="btn btn-primary btn-sm" id="preview-btn-dl">⬇ Download</a>
            ${isPdf ? `<a href="${blobUrl}" target="_blank" rel="noopener" class="btn btn-ghost btn-sm" title="Open in new browser tab">↗ New Tab</a>` : ''}
            <button class="preview-close-btn" id="preview-btn-close" aria-label="Close preview">✕</button>
          </div>
        </div>
        <div class="preview-content">
          ${bodyContent}
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
    document.body.classList.add('no-scroll');

    const handleClose = () => this.close();
    overlay.querySelector('#preview-btn-close')?.addEventListener('click', handleClose);
    overlay.querySelector('#preview-dl-unsupported')?.addEventListener('click', () => {
      FW.file.download(blob, filename);
    });

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) handleClose();
    });

    const keyListener = (e) => {
      if (e.key === 'Escape') {
        handleClose();
        document.removeEventListener('keydown', keyListener);
      }
    };
    document.addEventListener('keydown', keyListener);
  },

  close() {
    const existing = document.getElementById('fw-preview-modal');
    if (existing) {
      existing.remove();
      document.body.classList.remove('no-scroll');
    }
    if (this._activeBlobUrl) {
      URL.revokeObjectURL(this._activeBlobUrl);
      this._activeBlobUrl = null;
    }
  },
};

if (typeof window !== 'undefined') {
  window.PreviewModal = PreviewModal;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { PreviewModal };
}

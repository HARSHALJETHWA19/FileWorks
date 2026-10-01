// ============================================================
// FileWorks — Dedicated Result Screen Component
// Standardizes the post-processing result UI across all 13 tools.
// Includes Preview, Download, Download All, Share, Process Another File, Back to Home.
// ============================================================

const ResultScreen = {
  /**
   * Renders the complete result screen inside containerEl.
   * @param {HTMLElement} containerEl
   * @param {Object} options
   *   - title: string (e.g. "PDF Merged Successfully!")
   *   - description: string (e.g. "Your file is ready.")
   *   - files: Array<{ name: string, blob: Blob, originalSize?: number, compressedSize?: number }>
   *   - onReset: Function (callback when "Process Another File" is clicked)
   *   - onDownloadAllZip?: Function (optional custom ZIP download callback)
   *   - toolFeatureId?: string
   */
  render(containerEl, options) {
    if (!containerEl) return;
    const {
      title = 'Processing Complete!',
      description = 'Your files are ready to download.',
      files = [],
      onReset,
      onDownloadAllZip,
      toolFeatureId = '',
    } = options;

    containerEl.innerHTML = '';
    containerEl.classList.remove('hidden');

    const isMultiple = files.length > 1;

    const wrapper = document.createElement('div');
    wrapper.className = 'result-card-container fade-in';
    wrapper.id = 'fw-result-card';

    // Header
    const headerHtml = `
      <div class="result-header">
        <div class="result-header__icon" aria-hidden="true">✓</div>
        <h2 class="result-header__title">${title}</h2>
        <p class="result-header__desc">${description}</p>
      </div>
    `;

    // File list
    let filesHtml = '<div class="result-file-list" id="result-files-wrapper">';
    files.forEach((f, idx) => {
      const icon = FW.file.getIcon(f.name);
      const sizeStr = FW.file.formatSize(f.blob.size);
      let savingsHtml = '';
      if (f.originalSize && f.originalSize > f.blob.size) {
        const savedBytes = f.originalSize - f.blob.size;
        const pct = Math.round((savedBytes / f.originalSize) * 100);
        savingsHtml = `<span class="savings-tag">Saved ${pct}% (${FW.file.formatSize(savedBytes)})</span>`;
      }

      filesHtml += `
        <div class="result-file-item" data-file-index="${idx}">
          <div class="result-file-item__info">
            <span class="result-file-item__icon">${icon}</span>
            <div class="result-file-item__meta">
              <span class="result-file-item__name" title="${f.name}">${f.name}</span>
              <div class="result-file-item__details">
                <span class="result-file-item__size">${sizeStr}</span>
                ${savingsHtml}
              </div>
            </div>
          </div>
          <div class="result-file-item__actions">
            <button class="btn btn-outline btn-sm btn-preview-item" data-index="${idx}" title="Preview in browser">
              👁 Preview
            </button>
            <button class="btn btn-success btn-sm btn-download-item" data-index="${idx}" title="Download to device">
              ⬇ Download
            </button>
          </div>
        </div>
      `;
    });
    filesHtml += '</div>';

    // Main Actions
    const canShare = typeof navigator !== 'undefined' && !!navigator.share;
    let actionsHtml = `
      <div class="result-actions-toolbar">
        ${isMultiple ? `
          <button class="btn btn-success btn-lg" id="btn-result-download-all">
            ⬇ Download All ${files.length > 1 ? `as ZIP (${files.length})` : ''}
          </button>
        ` : `
          <button class="btn btn-success btn-lg" id="btn-result-download-single">
            ⬇ Download File
          </button>
        `}
        ${!isMultiple ? `
          <button class="btn btn-outline btn-lg" id="btn-result-preview-single">
            👁 Preview
          </button>
        ` : ''}
        ${canShare ? `
          <button class="btn btn-ghost btn-lg" id="btn-result-share" title="Share file">
            🔗 Share
          </button>
        ` : ''}
        <button class="btn btn-ghost btn-lg" id="btn-result-reset">
          🔄 Process Another File
        </button>
        <a href="/" class="btn btn-ghost btn-lg" id="btn-result-home">
          🏠 Back to Home
        </a>
      </div>
    `;

    // Local processing notice
    const privacyNoticeHtml = `
      <div class="result-privacy-badge">
        <span>🔒 Your files were processed locally in your browser and were never uploaded.</span>
      </div>
    `;

    // Ad slot: positioned safely below all buttons
    const adSlotHtml = `
      <div class="ad-container ad-container--banner" id="ad-result" style="margin-top:28px;" aria-label="Advertisement">
        <ins class="adsbygoogle"
             style="display:block"
             data-ad-client="ca-pub-7044469500687742"
             data-ad-format="auto"
             data-full-width-responsive="true"></ins>
      </div>
    `;

    wrapper.innerHTML = headerHtml + filesHtml + actionsHtml + privacyNoticeHtml + adSlotHtml;
    containerEl.appendChild(wrapper);

    // Bind item buttons
    containerEl.querySelectorAll('.btn-preview-item').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.index);
        const target = files[idx];
        if (target && window.PreviewModal) {
          PreviewModal.open(target.blob, target.name);
        }
      });
    });

    containerEl.querySelectorAll('.btn-download-item').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.index);
        const target = files[idx];
        if (target) {
          FW.file.download(target.blob, target.name);
          FW.analytics.track('download_started', { tool: toolFeatureId, name: target.name });
        }
      });
    });

    // Single item direct preview
    containerEl.querySelector('#btn-result-preview-single')?.addEventListener('click', () => {
      if (files[0] && window.PreviewModal) {
        PreviewModal.open(files[0].blob, files[0].name);
      }
    });

    // Single item direct download
    containerEl.querySelector('#btn-result-download-single')?.addEventListener('click', () => {
      if (files[0]) {
        FW.file.download(files[0].blob, files[0].name);
        FW.analytics.track('download_started', { tool: toolFeatureId, name: files[0].name });
      }
    });

    // Multi-download
    containerEl.querySelector('#btn-result-download-all')?.addEventListener('click', async () => {
      if (onDownloadAllZip) {
        onDownloadAllZip();
        return;
      }
      if (window.JSZip) {
        try {
          const zip = new JSZip();
          files.forEach(f => zip.file(f.name, f.blob));
          const zipBlob = await zip.generateAsync({
            type: 'blob',
            compression: 'DEFLATE',
            compressionOptions: { level: 6 },
          });
          const zipName = `${toolFeatureId || 'fileworks'}_bundle.zip`;
          FW.file.download(zipBlob, zipName);
          FW.analytics.track('download_started', { tool: toolFeatureId, type: 'zip_all' });
        } catch(e) {
          FW.toast.error('Failed to create ZIP bundle for download.');
        }
      } else {
        // Fallback: download individually with slight delay
        files.forEach((f, i) => {
          setTimeout(() => FW.file.download(f.blob, f.name), i * 300);
        });
      }
    });

    // Share button
    containerEl.querySelector('#btn-result-share')?.addEventListener('click', async () => {
      if (!navigator.share) {
        FW.toast.info('Direct sharing is not supported by your browser. Use Download instead.');
        return;
      }
      try {
        if (files[0] && navigator.canShare && navigator.canShare({ files: [new File([files[0].blob], files[0].name, { type: files[0].blob.type })] })) {
          const shareFile = new File([files[0].blob], files[0].name, { type: files[0].blob.type });
          await navigator.share({
            title: files[0].name,
            text: 'Processed with FileWorks',
            files: [shareFile],
          });
        } else {
          await navigator.share({
            title: 'FileWorks File Tools',
            text: 'I just processed my files locally with FileWorks!',
            url: window.location.href,
          });
        }
      } catch(e) {
        if (e.name !== 'AbortError') {
          FW.toast.info('Share cancelled or not supported.');
        }
      }
    });

    // Reset ("Process Another File")
    containerEl.querySelector('#btn-result-reset')?.addEventListener('click', () => {
      if (window.FreeUsageManager && toolFeatureId) {
        FreeUsageManager.resetAllowance(toolFeatureId);
      }
      if (window.PreviewModal) {
        PreviewModal.close();
      }
      containerEl.innerHTML = '';
      containerEl.classList.add('hidden');
      if (onReset) onReset();
    });

    // Try triggering AdSense in the new container if adsbygoogle is loaded
    try {
      if (window.adsbygoogle && Array.isArray(window.adsbygoogle)) {
        window.adsbygoogle.push({});
      }
    } catch(_) {}
  },
};

if (typeof window !== 'undefined') {
  window.ResultScreen = ResultScreen;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ResultScreen };
}

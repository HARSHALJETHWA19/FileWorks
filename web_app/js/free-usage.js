// ============================================================
// FileWorks — Centralized Free Usage Manager
// Enforces Android-parity free tier limits across all web tools.
// ============================================================

const FreeUsageConfig = {
  MB: 1024 * 1024,
  tools: {
    pdfMerge: {
      id: 'pdfMerge',
      name: 'Merge PDF',
      unit: 'PDFs',
      isByte: false,
      freeLimit: 3,
      allowance: 5,
      maxWithAllowance: 8,
      description: 'Merge up to 3 PDF files for free',
    },
    pdfSplit: {
      id: 'pdfSplit',
      name: 'Split PDF',
      unit: 'pages',
      isByte: false,
      freeLimit: 5,
      allowance: 5,
      maxWithAllowance: 10,
      description: 'Split up to 5 pages/selections for free',
    },
    pdfRotate: {
      id: 'pdfRotate',
      name: 'Rotate PDF',
      unit: 'pages',
      isByte: false,
      freeLimit: 5,
      allowance: 5,
      maxWithAllowance: 10,
      description: 'Rotate up to 5 pages for free',
    },
    pdfReorder: {
      id: 'pdfReorder',
      name: 'Reorder PDF',
      unit: 'pages',
      isByte: false,
      freeLimit: 10,
      allowance: 10,
      maxWithAllowance: 20,
      description: 'Reorder up to 10 pages for free',
    },
    pdfToImage: {
      id: 'pdfToImage',
      name: 'PDF to Image',
      unit: 'pages',
      isByte: false,
      freeLimit: 5,
      allowance: 5,
      maxWithAllowance: 10,
      description: 'Convert up to 5 PDF pages for free',
    },
    imageToPdf: {
      id: 'imageToPdf',
      name: 'Image to PDF',
      unit: 'images',
      isByte: false,
      freeLimit: 5,
      allowance: 5,
      maxWithAllowance: 10,
      description: 'Combine up to 5 images into PDF for free',
    },
    pdfCompress: {
      id: 'pdfCompress',
      name: 'Compress PDF',
      unit: 'MB',
      isByte: true,
      freeLimit: 10 * 1024 * 1024, // 10 MB
      allowance: 15 * 1024 * 1024, // +15 MB
      maxWithAllowance: 25 * 1024 * 1024, // 25 MB
      description: 'Compress PDFs up to 10 MB for free',
    },
    imageCompress: {
      id: 'imageCompress',
      name: 'Compress Image',
      unit: 'MB',
      isByte: true,
      freeLimit: 10 * 1024 * 1024, // 10 MB total
      allowance: 15 * 1024 * 1024,
      maxWithAllowance: 25 * 1024 * 1024,
      description: 'Compress images up to 10 MB total for free',
    },
    imageResize: {
      id: 'imageResize',
      name: 'Resize Image',
      unit: 'MB',
      isByte: true,
      freeLimit: 10 * 1024 * 1024, // 10 MB total
      allowance: 15 * 1024 * 1024,
      maxWithAllowance: 25 * 1024 * 1024,
      description: 'Resize images up to 10 MB total for free',
    },
    imageConvert: {
      id: 'imageConvert',
      name: 'Convert Image',
      unit: 'MB',
      isByte: true,
      freeLimit: 10 * 1024 * 1024, // 10 MB total
      allowance: 15 * 1024 * 1024,
      maxWithAllowance: 25 * 1024 * 1024,
      description: 'Convert images up to 10 MB total for free',
    },
    createZip: {
      id: 'createZip',
      name: 'Create ZIP',
      unit: 'files',
      isByte: false,
      freeLimit: 10,
      allowance: 10,
      maxWithAllowance: 20,
      description: 'Package up to 10 files into ZIP for free',
    },
    extractZip: {
      id: 'extractZip',
      name: 'Extract ZIP',
      unit: 'files',
      isByte: false,
      freeLimit: 10,
      allowance: 10,
      maxWithAllowance: 20,
      description: 'Extract up to 10 files from ZIP for free',
    },
    batchRename: {
      id: 'batchRename',
      name: 'Batch Rename',
      unit: 'files',
      isByte: false,
      freeLimit: 10,
      allowance: 10,
      maxWithAllowance: 20,
      description: 'Batch rename up to 10 files for free',
    },
  },

  getConfig(featureId) {
    const cfg = this.tools[featureId];
    if (!cfg) {
      throw new Error(`[FreeUsageConfig] Unknown tool feature "${featureId}"`);
    }
    return cfg;
  },
};

const FreeUsageManager = {
  // Ephemeral per-operation allowances (cleared on process reset / completion)
  _temporaryAllowances: new Set(),

  /**
   * Evaluates if the requested quantity/size is permitted.
   * @param {string} featureId
   * @param {number} requestedAmount (count or bytes)
   * @returns {Object} LimitCheckResult
   */
  checkLimit(featureId, requestedAmount) {
    const config = FreeUsageConfig.getConfig(featureId);
    const hasAllowance = this.hasTemporaryAllowance(featureId);
    const effectiveLimit = hasAllowance ? config.maxWithAllowance : config.freeLimit;
    const allowed = requestedAmount <= effectiveLimit;

    const formattedReq = config.isByte
      ? `${(requestedAmount / FreeUsageConfig.MB).toFixed(1)} MB`
      : `${requestedAmount} ${config.unit}`;

    const formattedLimit = config.isByte
      ? `${config.freeLimit / FreeUsageConfig.MB} MB`
      : `${config.freeLimit} ${config.unit}`;

    const message = allowed
      ? null
      : `Free limit reached. ${config.name} allows up to ${formattedLimit} with the free allowance. Choose fewer ${config.isByte ? 'or smaller files' : config.unit} to continue.`;

    return {
      allowed,
      featureId,
      name: config.name,
      unit: config.unit,
      isByte: config.isByte,
      requestedAmount,
      formattedReq,
      freeLimit: config.freeLimit,
      effectiveLimit,
      formattedLimit,
      maxWithAllowance: config.maxWithAllowance,
      hasAllowance,
      message,
    };
  },

  /**
   * Helper to calculate total size of multiple files in bytes.
   */
  calculateTotalSize(files) {
    if (!files || !files.length) return 0;
    return Array.from(files).reduce((sum, f) => sum + (f.size || 0), 0);
  },

  /**
   * Temporary allowance management.
   */
  grantTemporaryAllowance(featureId) {
    this._temporaryAllowances.add(featureId);
  },

  hasTemporaryAllowance(featureId) {
    return this._temporaryAllowances.has(featureId);
  },

  consumeAllowance(featureId) {
    this._temporaryAllowances.delete(featureId);
  },

  resetAllowance(featureId) {
    this._temporaryAllowances.delete(featureId);
  },

  resetAllAllowances() {
    this._temporaryAllowances.clear();
  },

  /**
   * Renders the standard Limit Banner directly inside a target container.
   */
  renderLimitWarning(containerEl, checkResult) {
    if (!containerEl) return;
    this.clearLimitWarning(containerEl);

    if (checkResult.allowed) return;

    const card = document.createElement('div');
    card.className = 'limit-warning-card fade-in';
    card.id = 'fw-limit-warning';
    card.setAttribute('role', 'alert');
    card.innerHTML = `
      <div class="limit-warning-header">
        <span class="limit-warning-icon" aria-hidden="true">⚠️</span>
        <h4 class="limit-warning-title">Free limit reached</h4>
      </div>
      <p class="limit-warning-body">
        <strong>${checkResult.name}</strong> allows up to <strong>${checkResult.formattedLimit}</strong> with the free allowance.
      </p>
      <p class="limit-warning-sub">
        You selected <strong>${checkResult.formattedReq}</strong>. Choose fewer ${checkResult.isByte ? 'or smaller files' : checkResult.unit} to continue.
      </p>
    `;

    containerEl.prepend(card);
    card.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  },

  clearLimitWarning(containerEl) {
    if (!containerEl) return;
    const existing = containerEl.querySelector('#fw-limit-warning');
    if (existing) existing.remove();
  },

  /**
   * Renders a modal if user attempts to process while over limit.
   */
  showLimitModal(checkResult) {
    const existing = document.getElementById('fw-limit-modal');
    if (existing) existing.remove();

    const overlay = document.createElement('div');
    overlay.id = 'fw-limit-modal';
    overlay.className = 'modal-overlay fade-in';
    overlay.innerHTML = `
      <div class="modal-card" role="dialog" aria-labelledby="limit-modal-title">
        <div class="modal-header">
          <div style="display:flex;align-items:center;gap:10px;">
            <span style="font-size:24px;">⚠️</span>
            <h3 id="limit-modal-title" style="margin:0;font-size:1.25rem;">Free limit reached</h3>
          </div>
          <button class="modal-close-btn" id="limit-modal-close" aria-label="Close">✕</button>
        </div>
        <div class="modal-body" style="padding:20px 0;line-height:1.6;">
          <p style="margin-bottom:12px;color:var(--color-text);">
            <strong>${checkResult.name}</strong> allows up to <strong>${checkResult.formattedLimit}</strong> with the free allowance.
          </p>
          <div style="background:var(--color-surface-2);border:1px solid var(--color-border);border-radius:var(--radius-md);padding:14px;margin-bottom:14px;">
            <div style="display:flex;justify-content:space-between;font-size:.875rem;margin-bottom:4px;">
              <span style="color:var(--color-text-muted);">Selected:</span>
              <span style="color:var(--color-danger);font-weight:600;">${checkResult.formattedReq}</span>
            </div>
            <div style="display:flex;justify-content:space-between;font-size:.875rem;">
              <span style="color:var(--color-text-muted);">Free limit:</span>
              <span style="color:var(--color-success);font-weight:600;">${checkResult.formattedLimit}</span>
            </div>
          </div>
          <p style="font-size:.875rem;color:var(--color-text-muted);">
            Please choose fewer ${checkResult.isByte ? 'or smaller files' : checkResult.unit} to continue. All tools on FileWorks are 100% free with local processing.
          </p>
        </div>
        <div class="modal-footer" style="display:flex;justify-content:flex-end;gap:10px;">
          <button class="btn btn-primary" id="limit-modal-ok">Choose Fewer Files</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    const close = () => overlay.remove();
    overlay.querySelector('#limit-modal-close')?.addEventListener('click', close);
    overlay.querySelector('#limit-modal-ok')?.addEventListener('click', close);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) close();
    });
  },
};

// Export globally for browser & module environments
if (typeof window !== 'undefined') {
  window.FreeUsageConfig = FreeUsageConfig;
  window.FreeUsageManager = FreeUsageManager;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { FreeUsageConfig, FreeUsageManager };
}

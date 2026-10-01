// ============================================================
// FileWorks Web App — Core Application Module
// ============================================================

const FW = {
  // ---- Configuration ----
  config: {
    siteUrl: (typeof SITE_URL !== 'undefined') ? SITE_URL : window.location.origin,
    adSensePublisherId: (typeof ADSENSE_ID !== 'undefined') ? ADSENSE_ID : '',
    maxFileSizeMB: 200,
    maxPdfPagesMerge: 50,
    version: '1.0.0',
  },

  // ---- Toast Notifications ----
  toast: {
    container: null,
    init() {
      this.container = document.getElementById('toast-container');
      if (!this.container) {
        this.container = document.createElement('div');
        this.container.id = 'toast-container';
        this.container.className = 'toast-container';
        document.body.appendChild(this.container);
      }
    },
    show(message, type = 'info', duration = 4000) {
      if (!this.container) this.init();
      const el = document.createElement('div');
      el.className = `toast toast--${type}`;
      const icons = { success: '✓', error: '✕', info: 'ℹ', warning: '⚠' };
      el.textContent = `${icons[type] || ''} ${message}`;
      this.container.appendChild(el);
      setTimeout(() => {
        el.style.animation = 'toast-in 0.3s ease reverse';
        setTimeout(() => el.remove(), 300);
      }, duration);
    },
    success(msg) { this.show(msg, 'success'); },
    error(msg)   { this.show(msg, 'error', 6000); },
    info(msg)    { this.show(msg, 'info'); },
    warning(msg) { this.show(msg, 'warning'); },
  },

  // ---- File Utils ----
  file: {
    formatSize(bytes) {
      if (bytes === 0) return '0 B';
      const k = 1024;
      const sizes = ['B', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
    },
    getIcon(filename) {
      const ext = (filename.split('.').pop() || '').toLowerCase();
      const icons = {
        pdf: '📄', jpg: '🖼️', jpeg: '🖼️', png: '🖼️', webp: '🖼️',
        gif: '🎞️', zip: '🗜️', txt: '📝', doc: '📝', docx: '📝',
        mp4: '🎬', mp3: '🎵', svg: '🎨', bmp: '🖼️',
      };
      return icons[ext] || '📎';
    },
    sanitizeName(name) {
      return name.replace(/[<>:"/\\|?*\x00-\x1f]/g, '_').trim().replace(/\.{2,}/g, '.');
    },
    validateSize(file, maxMB = 200) {
      if (file.size > maxMB * 1024 * 1024) {
        throw new Error(`File "${file.name}" exceeds the ${maxMB} MB size limit.`);
      }
    },
    validateType(file, allowedTypes) {
      const ext = (file.name.split('.').pop() || '').toLowerCase();
      if (!allowedTypes.includes(ext)) {
        throw new Error(`File type ".${ext}" is not supported. Allowed: ${allowedTypes.join(', ')}`);
      }
    },
    async readAsArrayBuffer(file) {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = e => resolve(e.target.result);
        reader.onerror = () => reject(new Error('Failed to read file.'));
        reader.readAsArrayBuffer(file);
      });
    },
    async readAsDataURL(file) {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = e => resolve(e.target.result);
        reader.onerror = () => reject(new Error('Failed to read file.'));
        reader.readAsDataURL(file);
      });
    },
    download(blob, filename) {
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      setTimeout(() => {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }, 100);
    },
  },

  // ---- Dropzone Helper ----
  dropzone: {
    init(zoneEl, inputEl, onFiles, options = {}) {
      const { accept = '', multiple = true } = options;
      if (accept) inputEl.setAttribute('accept', accept);
      if (multiple) inputEl.setAttribute('multiple', '');

      zoneEl.addEventListener('dragover', e => {
        e.preventDefault();
        zoneEl.classList.add('drag-over');
      });
      zoneEl.addEventListener('dragleave', () => zoneEl.classList.remove('drag-over'));
      zoneEl.addEventListener('drop', e => {
        e.preventDefault();
        zoneEl.classList.remove('drag-over');
        const files = Array.from(e.dataTransfer.files);
        if (files.length) onFiles(files);
      });
      inputEl.addEventListener('change', e => {
        const files = Array.from(e.target.files || []);
        if (files.length) { onFiles(files); e.target.value = ''; }
      });
    },
  },

  // ---- Nav ----
  nav: {
    init() {
      const btn = document.getElementById('nav-menu-btn');
      const menu = document.getElementById('nav-mobile-menu');
      if (btn && menu) {
        btn.addEventListener('click', () => menu.classList.toggle('open'));
        document.addEventListener('click', e => {
          if (!btn.contains(e.target) && !menu.contains(e.target)) menu.classList.remove('open');
        });
      }
      // Mark active link
      const current = window.location.pathname;
      document.querySelectorAll('.nav__link, .nav-mobile-menu a').forEach(a => {
        if (a.getAttribute('href') === current) a.classList.add('active');
      });
    },
  },

  // ---- Cookie Consent ----
  consent: {
    KEY: 'fw_cookie_consent',
    init() {
      if (localStorage.getItem(this.KEY)) return;
      const banner = document.getElementById('cookie-banner');
      if (!banner) return;
      banner.classList.remove('hidden');
      document.getElementById('cookie-accept')?.addEventListener('click', () => {
        localStorage.setItem(this.KEY, 'accepted');
        banner.classList.add('hidden');
        FW.ads.loadAds();
      });
      document.getElementById('cookie-decline')?.addEventListener('click', () => {
        localStorage.setItem(this.KEY, 'declined');
        banner.classList.add('hidden');
      });
    },
    isAccepted() { return localStorage.getItem(this.KEY) === 'accepted'; },
  },

  // ---- AdSense ----
  ads: {
    loaded: false,
    loadAds() {
      if (this.loaded) return;
      if (!FW.config.adSensePublisherId) return; // No ID configured
      if (!FW.consent.isAccepted()) return;      // Wait for consent
      // Load AdSense script
      const s = document.createElement('script');
      s.async = true;
      s.crossOrigin = 'anonymous';
      s.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${FW.config.adSensePublisherId}`;
      document.head.appendChild(s);
      this.loaded = true;
    },
  },

  // ---- Analytics (Privacy-safe) ----
  analytics: {
    track(event, data = {}) {
      // Only log tool events — never file names/contents
      try {
        const allowed = ['tool_open','file_selected','processing_started','processing_completed','download_started','error_occurred'];
        if (!allowed.includes(event)) return;
        // If GA is loaded (future), send event
        if (typeof gtag === 'function') {
          gtag('event', event, data);
        }
      } catch(_) {}
    },
  },

  // ---- Init ----
  init() {
    FW.toast.init();
    FW.nav.init();
    FW.consent.init();
    if (FW.consent.isAccepted()) FW.ads.loadAds();
  },
};

// Auto-init when DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => FW.init());
} else {
  FW.init();
}

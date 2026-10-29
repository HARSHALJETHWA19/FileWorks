// ============================================================
// FileWorks Web App — Core Application Module
// ============================================================

const FW = {
  // ---- Configuration ----
  config: {
    siteUrl: 'https://fileworks.pages.dev',
    adSensePublisherId: 'ca-pub-7044469500687742',
    maxFileSizeMB: 200,
    maxPdfPagesMerge: 8,
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

  // ---- Consent Management (Independent & Granular) ----
  consent: {
    KEY: 'fw_cookie_consent',
    // Granular categories: Essential is always enabled for site functionality.
    // Advertising consent requires explicit affirmative opt-in.
    init() {
      if (this.hasUserResponded()) return;
      const banner = document.getElementById('cookie-banner');
      if (!banner) return;
      banner.classList.remove('hidden');

      document.getElementById('cookie-accept')?.addEventListener('click', () => {
        this.setAdvertisingConsent(true);
        banner.classList.add('hidden');
        FW.onConsentGranted();
      });

      document.getElementById('cookie-decline')?.addEventListener('click', () => {
        this.setAdvertisingConsent(false);
        banner.classList.add('hidden');
      });
    },
    hasUserResponded() {
      const val = localStorage.getItem(this.KEY);
      return val === 'accepted' || val === 'declined';
    },
    isAdConsentGranted() {
      // Essential consent does NOT imply advertising consent.
      // Advertising scripts only run if explicitly accepted.
      return localStorage.getItem(this.KEY) === 'accepted';
    },
    isEssentialOnly() {
      return !this.isAdConsentGranted();
    },
    isAccepted() {
      // Backward-compatible alias
      return this.isAdConsentGranted();
    },
    setAdvertisingConsent(granted) {
      localStorage.setItem(this.KEY, granted ? 'accepted' : 'declined');
    },
  },

  // ---- Google AdSense Module (Independent & Suspended Guarded) ----
  ads: {
    loaded: false,
    error: null,
    // Status flag: AdSense account is currently temporarily suspended.
    // Strictly set enabled to false to avoid triggering ad calls while under review.
    enabled: false,
    suspended: true,
    config: {
      publisherId: 'ca-pub-7044469500687742',
    },
    loadAds() {
      // Strictly do not load or re-enable AdSense serving while account is suspended
      if (this.suspended || !this.enabled) {
        console.info('[FW.ads] Google AdSense serving paused: account currently suspended pending review.');
        return;
      }
      if (this.loaded) return;
      if (!FW.consent.isAdConsentGranted()) return; // Advertising consent gate

      const existing = document.querySelector('script[src*="googlesyndication.com/pagead/js/adsbygoogle.js"]');
      if (!existing && this.config.publisherId) {
        const s = document.createElement('script');
        s.async = true;
        s.crossOrigin = 'anonymous';
        s.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${this.config.publisherId}`;
        s.onerror = (err) => {
          this.error = err;
          console.warn('[FW.ads] AdSense script failed to load:', err);
        };
        document.head.appendChild(s);
      }
      this.loaded = true;
    },
  },

  // ---- Monetag Module (Independent, Isolated, Non-Intrusive Only) ----
  monetag: {
    loaded: false,
    error: null,
    navigationGuarded: false,
    // Status flag: Controlled testing enabled for verified In-Page Push zone 12147932.
    enabled: true,
    status: 'controlled_testing_in_page_push',
    config: {
      zone: '12147932',
      src: 'https://nap5k.com/tag.min.js',
      format: 'in-page-push',
      // Old zone 303303 (quge5.com) is retired and strictly disabled
      retiredZone: '303303',
      // Prohibited intrusive formats under AdSense & Better Ads policies
      prohibitedFormats: ['popunder', 'directlink', 'forced_redirect', 'vignette'],
      allowedFormats: ['in-page-push'],
    },
    // Defensive navigation guard: blocks unprompted popunders and unwanted page hijacking
    installNavigationGuard() {
      if (this.navigationGuarded) return;
      this.navigationGuarded = true;

      // Wrap window.open to block unauthorized popunders
      const originalWindowOpen = window.open;
      window.open = function(url, target, features) {
        // Allow user-initiated file downloads and internal navigation
        if (!url || typeof url !== 'string' || url.startsWith('blob:') || url.startsWith('data:') || url.startsWith('/')) {
          return originalWindowOpen.apply(window, arguments);
        }
        // Allow legitimate user clicks on interactive elements
        const activeEl = document.activeElement;
        const isUserClick = activeEl && (activeEl.tagName === 'A' || activeEl.tagName === 'BUTTON');
        if (isUserClick) {
          return originalWindowOpen.apply(window, arguments);
        }
        // Block unprompted popunders or forced background redirects
        console.warn('[FW.monetag] Blocked unprompted background window.open request:', url);
        return null;
      };
    },
    load() {
      // Must not load until enabled and explicit advertising consent is verified
      if (!this.enabled) {
        console.info('[FW.monetag] Monetag tag is currently disabled.');
        return;
      }
      if (this.loaded) return;

      // Restrict Monetag to production HTTPS environment only
      const isProduction = window.location.protocol === 'https:' &&
        !['localhost', '127.0.0.1', '0.0.0.0'].includes(window.location.hostname) &&
        !window.location.hostname.endsWith('.local');

      if (!isProduction) return;

      // Consent Gate: Advertising consent required (Essential consent does NOT suffice)
      if (!FW.consent.isAdConsentGranted()) return;

      // Install popunder & redirect defense guard
      this.installNavigationGuard();

      // Duplicate prevention (DOM check + internal flag)
      const existing = document.querySelector(`script[data-zone="${this.config.zone}"]`) ||
        document.querySelector('script[src*="nap5k.com"]');
      if (existing) {
        this.loaded = true;
        return;
      }

      const script = document.createElement('script');
      script.src = this.config.src;
      script.setAttribute('data-zone', this.config.zone);
      script.async = true;
      script.setAttribute('data-cfasync', 'false');

      script.onload = () => {
        this.loaded = true;
      };
      script.onerror = (e) => {
        this.error = e;
        console.warn('[FW.monetag] Monetag script load error:', e);
      };

      document.head.appendChild(script);
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
        if (typeof gtag === 'function') {
          gtag('event', event, data);
        }
      } catch(_) {}
    },
  },

  // ---- Service Worker Registration (Disabled for Maximum AdSense Compatibility) ----
  sw: {
    registered: false,
    registering: false,
    error: null,
    // Push service worker registration is disabled to prevent unprompted notifications
    enabled: false,
    status: 'disabled',
    init() {
      // Strictly do not register service worker while disabled
      if (!this.enabled) {
        // Clean up any previously registered service worker on this origin
        if ('serviceWorker' in navigator) {
          navigator.serviceWorker.getRegistration('/').then(reg => {
            if (reg) {
              reg.unregister();
              console.info('[FW.sw] Unregistered existing push service worker.');
            }
          }).catch(() => {});
        }
        return;
      }
      if (this.registered || this.registering) return;
      if (!('serviceWorker' in navigator)) return;

      const isProduction = window.location.protocol === 'https:' &&
        !['localhost', '127.0.0.1', '0.0.0.0'].includes(window.location.hostname) &&
        !window.location.hostname.endsWith('.local');

      if (!isProduction) return;

      // Advertising consent required before registering monetization push worker
      if (!FW.consent.isAdConsentGranted()) return;

      this.registering = true;
      const register = () => {
        navigator.serviceWorker.getRegistration('/').then(existingReg => {
          if (existingReg) {
            this.registered = true;
            this.registering = false;
            return;
          }
          navigator.serviceWorker.register('/sw.js', { scope: '/' })
            .then(() => {
              this.registered = true;
              this.registering = false;
            })
            .catch(err => {
              this.error = err;
              this.registering = false;
              console.warn('[FW.sw] Service worker registration failed:', err);
            });
        }).catch(() => {
          navigator.serviceWorker.register('/sw.js', { scope: '/' })
            .then(() => {
              this.registered = true;
              this.registering = false;
            })
            .catch(err => {
              this.error = err;
              this.registering = false;
              console.warn('[FW.sw] Service worker registration fallback failed:', err);
            });
        });
      };

      if (document.readyState === 'complete') {
        register();
      } else {
        window.addEventListener('load', register, { once: true });
      }
    },
  },

  onConsentGranted() {
    // Isolated network activations: failure or state in one does not affect the other
    try { FW.ads.loadAds(); } catch (e) { console.error('[FW.ads]', e); }
    try { FW.monetag.load(); } catch (e) { console.error('[FW.monetag]', e); }
    // Service worker registration call site omitted while disabled
  },

  // ---- Init ----
  init() {
    FW.toast.init();
    FW.nav.init();
    FW.consent.init();
    if (FW.consent.isAdConsentGranted()) {
      this.onConsentGranted();
    }
  },
};

// Auto-init when DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => FW.init());
} else {
  FW.init();
}

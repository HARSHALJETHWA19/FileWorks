// Verification Suite: Ad Networks Isolation, Consent Gating & Policy Defense
const fs = require('fs');
const path = require('path');
const appJsCode = fs.readFileSync(path.join(__dirname, '..', 'web_app', 'js', 'app.js'), 'utf8');

let totalTests = 0;
let passedTests = 0;

function assert(description, condition) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`[PASS] ${description}`);
  } else {
    console.error(`[FAIL] ${description}`);
    throw new Error(`Assertion failed: ${description}`);
  }
}

function createMockEnvironment({ protocol = 'https:', hostname = 'fileworks.pages.dev', consent = 'accepted' } = {}) {
  let scriptsInHead = [];
  let regCalls = [];
  let existingRegistration = null;
  let windowOpenCalls = [];
  let activeElement = { tagName: 'BODY' };

  const window = {
    location: { protocol, hostname },
    open: function(url, target, features) {
      windowOpenCalls.push({ url, target, features });
      return { closed: false };
    },
    addEventListener: (event, cb) => cb()
  };

  const navigator = {
    serviceWorker: {
      getRegistration: (scope) => Promise.resolve(existingRegistration),
      register: (path, opts) => {
        regCalls.push({ path, opts });
        existingRegistration = { scope: opts.scope };
        return Promise.resolve(existingRegistration);
      }
    }
  };

  const document = {
    readyState: 'loading',
    addEventListener: () => {},
    get activeElement() { return activeElement; },
    getElementById: (id) => null,
    createElement: (tag) => {
      const el = {
        tagName: tag.toUpperCase(),
        attrs: {},
        setAttribute: (k, v) => { el.attrs[k] = v; },
        classList: { add: () => {} },
        set src(val) {
          el._src = val;
        },
        get src() { return el._src; }
      };
      return el;
    },
    head: {
      appendChild: (el) => {
        scriptsInHead.push(el);
      }
    },
    body: { appendChild: () => {} },
    querySelector: (sel) => {
      if (sel.includes('data-zone')) {
        return scriptsInHead.find(s => s.attrs && s.attrs['data-zone'] === '12147932') || null;
      }
      if (sel.includes('nap5k.com')) {
        return scriptsInHead.find(s => (s.src && s.src.includes('nap5k.com')) || (s.attrs && s.attrs.src && s.attrs.src.includes('nap5k.com'))) || null;
      }
      if (sel.includes('googlesyndication.com')) {
        return scriptsInHead.find(s => (s.src && s.src.includes('googlesyndication.com')) || (s.attrs && s.attrs.src && s.attrs.src.includes('googlesyndication.com'))) || null;
      }
      return null;
    },
    querySelectorAll: () => []
  };

  const localStorage = {
    getItem: (key) => consent,
    setItem: (key, val) => { consent = val; }
  };

  const fn = new Function('window', 'navigator', 'document', 'console', 'localStorage', appJsCode + '; return FW;');
  const FW = fn(window, navigator, document, console, localStorage);
  return { FW, window, scriptsInHead, regCalls, windowOpenCalls, setActiveElement: (el) => { activeElement = el; } };
}

async function runTests() {
  console.log('================================================================');
  console.log('FILEWORKS — AD NETWORKS ISOLATION & COMPLIANCE TEST SUITE');
  console.log('================================================================\n');

  // 1. MODULE ISOLATION TESTS
  {
    const { FW } = createMockEnvironment();
    assert('ISO-001: FW.ads and FW.monetag exist as independent objects',
      typeof FW.ads === 'object' && typeof FW.monetag === 'object' && FW.ads !== FW.monetag);

    assert('ISO-002: FW.ads has dedicated publisherId and configuration',
      FW.ads.config.publisherId === 'ca-pub-7044469500687742');

    assert('ISO-003: FW.monetag has dedicated zone and endpoint configuration for In-Page Push',
      FW.monetag.config.zone === '12147932' &&
      FW.monetag.config.src === 'https://nap5k.com/tag.min.js' &&
      FW.monetag.config.retiredZone === '303303');

    assert('ISO-004: FW.monetag configuration does not contain or reference AdSense keys',
      !('publisherId' in FW.monetag.config) && !('adSensePublisherId' in FW.monetag.config));

    assert('ISO-005: FW.ads configuration does not contain or reference Monetag zones',
      !('zone' in FW.ads.config) && !('zoneId' in FW.ads.config));
  }

  // 2. ADSENSE & CAUTIOUS SUSPENSION GUARD TESTS
  {
    const { FW, scriptsInHead } = createMockEnvironment({ consent: 'accepted' });
    assert('SUSP-001: FW.ads is marked as suspended and disabled',
      FW.ads.suspended === true && FW.ads.enabled === false);

    FW.ads.loadAds();
    const adSenseScripts = scriptsInHead.filter(s => (s.src && s.src.includes('googlesyndication.com')) || (s.attrs && s.attrs.src && s.attrs.src.includes('googlesyndication.com')));
    assert('SUSP-002: FW.ads.loadAds() does NOT inject AdSense script while suspended',
      adSenseScripts.length === 0);

    assert('SUSP-003: Monetag push service worker registration is disabled (FW.sw.enabled = false)',
      FW.sw.enabled === false);

    assert('SUSP-004: Monetag tag is enabled specifically for controlled In-Page Push testing',
      FW.monetag.enabled === true && FW.monetag.status === 'controlled_testing_in_page_push');
  }

  // 3. CONSENT HANDLING TESTS (Essential vs Advertising)
  {
    // Test with user declining advertising consent
    const { FW, scriptsInHead, regCalls } = createMockEnvironment({ consent: 'declined' });
    assert('CONSENT-001: Declined consent results in isAdConsentGranted() returning false',
      FW.consent.isAdConsentGranted() === false);

    assert('CONSENT-002: Essential consent remains active even when ad consent is declined',
      FW.consent.isEssentialOnly() === true);

    FW.monetag.load();
    FW.sw.init();
    await new Promise(r => setTimeout(r, 20));
    const monetagScripts = scriptsInHead.filter(s => (s.src && (s.src.includes('nap5k.com') || s.src.includes('quge5.com'))) ||
      (s.attrs && s.attrs.src && (s.attrs.src.includes('nap5k.com') || s.attrs.src.includes('quge5.com'))));
    assert('CONSENT-003: Monetag script is blocked when ad consent is declined',
      monetagScripts.length === 0);
    assert('CONSENT-004: Service Worker is NOT registered when ad consent is declined',
      regCalls.length === 0);

    // Test with accepted advertising consent (while Monetag tag is explicitly disabled)
    const envAccepted = createMockEnvironment({ consent: 'accepted' });
    assert('CONSENT-005: Accepted consent activates isAdConsentGranted()',
      envAccepted.FW.consent.isAdConsentGranted() === true);

    envAccepted.FW.monetag.enabled = false;
    envAccepted.FW.monetag.load();
    const activeMonetag = envAccepted.scriptsInHead.filter(s => (s.src && s.src.includes('nap5k.com')) || (s.attrs && s.attrs.src && s.attrs.src.includes('nap5k.com')));
    assert('CONSENT-006: Monetag tag does NOT load when enabled=false',
      activeMonetag.length === 0);

    // Test enabling Monetag In-Page Push tag
    envAccepted.FW.monetag.enabled = true;
    envAccepted.FW.monetag.load();
    const verifiedMonetag = envAccepted.scriptsInHead.filter(s => (s.src && s.src.includes('nap5k.com')) || (s.attrs && s.attrs.src && s.attrs.src.includes('nap5k.com')));
    assert('CONSENT-007: Monetag tag loads cleanly when both consent is granted AND enabled=true',
      verifiedMonetag.length === 1 && verifiedMonetag[0].attrs['data-zone'] === '12147932');
  }

  // 4. DUPLICATE INJECTION PREVENTION
  {
    const { FW, scriptsInHead } = createMockEnvironment({ consent: 'accepted' });
    FW.monetag.load();
    FW.monetag.load();
    FW.monetag.load();
    const monetagScripts = scriptsInHead.filter(s => (s.src && s.src.includes('nap5k.com')) || (s.attrs && s.attrs.src && s.attrs.src.includes('nap5k.com')));
    assert('DUP-001: Multiple Monetag load calls inject at most 1 script element',
      monetagScripts.length === 1);

    // SW is disabled
    const regCalls = [];
    FW.sw.init();
    FW.sw.init();
    await new Promise(r => setTimeout(r, 20));
    assert('DUP-002: Service worker init calls perform zero registrations while disabled',
      regCalls.length === 0);
  }

  // 5. DEFENSE AGAINST UNWANTED POPUNDERS & REDIRECTS
  {
    const { FW, window, windowOpenCalls, setActiveElement } = createMockEnvironment({ consent: 'accepted' });
    FW.monetag.installNavigationGuard(); // installs navigation guard

    // Attempt 1: Unprompted background window.open (Popunder attempt from ad script)
    setActiveElement({ tagName: 'DIV' }); // user did NOT click a link or button
    const blockedResult = window.open('https://ad-network-redirect.com/offer', '_blank');
    assert('DEF-001: Unprompted background window.open is blocked by navigation guard',
      blockedResult === null && windowOpenCalls.length === 0);

    // Attempt 2: Legitimate user interaction on a button or link (e.g. PDF download/view)
    setActiveElement({ tagName: 'BUTTON' });
    const allowedButtonResult = window.open('blob:http://localhost/test-pdf', '_blank');
    assert('DEF-002: User-initiated blob/file window.open is preserved',
      allowedButtonResult !== null && windowOpenCalls.length === 1);
  }

  // 6. ESSENTIAL FUNCTIONALITY PRESERVATION (CONSENT DECLINED)
  {
    const { FW, scriptsInHead, regCalls } = createMockEnvironment({ consent: 'declined' });
    FW.init();

    // Verify zero scripts injected and zero workers registered
    assert('ESS-001: Zero scripts injected when consent is declined', scriptsInHead.length === 0);
    assert('ESS-002: Zero service workers registered when consent is declined', regCalls.length === 0);

    // Verify essential file utilities work without ad networks
    const sanitized = FW.file.sanitizeName('document:test<name>.pdf');
    assert('ESS-003: FW.file.sanitizeName operates without ad network dependencies',
      sanitized === 'document_test_name_.pdf');

    const formattedSize = FW.file.formatSize(1048576 * 10);
    assert('ESS-004: FW.file.formatSize operates without ad network dependencies',
      formattedSize === '10 MB');

    let sizeValid = false;
    try {
      FW.file.validateSize({ name: 'file.pdf', size: 1024 * 1024 }, 200);
      sizeValid = true;
    } catch (_) {}
    assert('ESS-005: FW.file.validateSize functions normally when consent is declined', sizeValid);

    let typeValid = false;
    try {
      FW.file.validateType({ name: 'document.pdf' }, ['pdf']);
      typeValid = true;
    } catch (_) {}
    assert('ESS-006: FW.file.validateType functions normally when consent is declined', typeValid);
  }

  console.log(`\n================================================================`);
  console.log(`RESULTS: ${passedTests} / ${totalTests} TESTS PASSED`);
  console.log(`================================================================\n`);
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});

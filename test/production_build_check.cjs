// Production-Build & Network Traffic Security Audit
// Verifies complete absence of AdSense requests during suspension, scans all HTML files, and audits network calls.
const fs = require('fs');
const path = require('path');

const webAppDir = path.join(__dirname, '..', 'web_app');
let passed = 0;
let failed = 0;

function assert(id, description, condition) {
  if (condition) {
    passed++;
    console.log(`[PASS] ${id}: ${description}`);
  } else {
    failed++;
    console.error(`[FAIL] ${id}: ${description}`);
  }
}

console.log('================================================================');
console.log('FILEWORKS — PRODUCTION-BUILD & NETWORK COMPLIANCE CHECK');
console.log('================================================================\n');

// 1. SCAN ALL HTML FILES FOR REMAINING ADSENSE SCRIPT TAGS
console.log('--- 1. Scanning All HTML Files for AdSense Script Tags ---');
let allHtmlFiles = [];
function findHtmlFiles(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      findHtmlFiles(fullPath);
    } else if (file.endsWith('.html')) {
      allHtmlFiles.push(fullPath);
    }
  }
}
findHtmlFiles(webAppDir);

let filesWithAdSense = [];
const adSensePattern = /pagead2\.googlesyndication\.com/i;
for (const file of allHtmlFiles) {
  const content = fs.readFileSync(file, 'utf8');
  if (adSensePattern.test(content)) {
    filesWithAdSense.push(path.relative(webAppDir, file));
  }
}

assert('BUILD-001', `Found ${allHtmlFiles.length} HTML files in web_app/`, allHtmlFiles.length >= 30);
assert('BUILD-002', 'Zero HTML files contain static AdSense script tags', filesWithAdSense.length === 0);
if (filesWithAdSense.length > 0) {
  console.error('Remaining in files:', filesWithAdSense);
}

// 2. VERIFY MONETAG INTEGRATION AND EXACT ENDPOINTS
console.log('\n--- 2. Auditing Monetag Script & Service Worker Configuration ---');
const appJsPath = path.join(webAppDir, 'js', 'app.js');
const appJs = fs.readFileSync(appJsPath, 'utf8');

assert('BUILD-003', 'Monetag zone ID 303303 configured in app.js',
  appJs.includes("zone: '303303'"));

assert('BUILD-004', 'Monetag script URL https://quge5.com/88/tag.min.js configured in app.js',
  appJs.includes("src: 'https://quge5.com/88/tag.min.js'"));

const swRootPath = path.join(webAppDir, 'sw.js');
const swPublicPath = path.join(webAppDir, 'public', 'sw.js');
const swRoot = fs.readFileSync(swRootPath, 'utf8');
const swPublic = fs.readFileSync(swPublicPath, 'utf8');

assert('BUILD-005', 'sw.js references domain 3nbf4.com and zone 12147235',
  swRoot.includes('3nbf4.com') && swRoot.includes('12147235'));

assert('BUILD-006', 'public/sw.js matches root sw.js exactly',
  swRoot.trim() === swPublic.trim());

// 3. AUDIT BROWSER NETWORK REQUESTS DURING SESSION SIMULATION
console.log('\n--- 3. Browser Network Log Verification (Google Ad Endpoints) ---');
let networkRequests = [];

function runSimulation(consentValue) {
  networkRequests = [];
  let scriptNodes = [];

  const window = {
    location: { protocol: 'https:', hostname: 'fileworks.pages.dev' },
    open: () => {},
    addEventListener: (e, cb) => cb()
  };

  const navigator = {
    serviceWorker: {
      getRegistration: () => Promise.resolve(null),
      register: (path) => {
        networkRequests.push({ type: 'sw', url: path });
        return Promise.resolve({});
      }
    }
  };

  const document = {
    readyState: 'complete',
    getElementById: () => null,
    createElement: (tag) => {
      const el = {
        tagName: tag.toUpperCase(),
        attrs: {},
        setAttribute: (k, v) => { el.attrs[k] = v; },
        classList: { add: () => {} },
        set src(val) {
          el._src = val;
          networkRequests.push({ type: 'script', url: val });
        },
        get src() { return el._src; }
      };
      return el;
    },
    head: {
      appendChild: (el) => {
        scriptNodes.push(el);
      }
    },
    body: { appendChild: () => {}, removeChild: () => {} },
    querySelector: () => null,
    querySelectorAll: () => []
  };

  const localStorage = {
    getItem: (k) => consentValue,
    setItem: () => {}
  };

  const fn = new Function('window', 'navigator', 'document', 'console', 'localStorage', appJs + '; return FW;');
  const FW = fn(window, navigator, document, console, localStorage);
  return { FW, networkRequests };
}

// Simulation A: Consent Declined
{
  const { FW, networkRequests } = runSimulation('declined');
  FW.init();
  const googleAdRequests = networkRequests.filter(r =>
    r.url.includes('googlesyndication') || r.url.includes('doubleclick') || r.url.includes('googleadservices')
  );
  assert('NET-001', 'Zero requests to Google ad-serving endpoints when consent is declined',
    googleAdRequests.length === 0);
  assert('NET-002', 'Zero requests to Monetag when consent is declined',
    networkRequests.filter(r => r.url.includes('quge5.com')).length === 0);
}

// Simulation B: Consent Accepted (AdSense Suspended)
{
  const { FW, networkRequests } = runSimulation('accepted');
  FW.init();
  const googleAdRequests = networkRequests.filter(r =>
    r.url.includes('googlesyndication') || r.url.includes('doubleclick') || r.url.includes('googleadservices')
  );
  assert('NET-003', 'Zero requests to Google ad-serving endpoints even when consent is ACCEPTED (Suspension Respected)',
    googleAdRequests.length === 0);

  const monetagRequests = networkRequests.filter(r => r.url.includes('quge5.com'));
  assert('NET-004', 'Monetag loads cleanly and independently when consent is accepted',
    monetagRequests.length === 1);
}

// 4. VERIFY POPUNDER GUARD & PDF TOOLS PRESERVATION
console.log('\n--- 4. Preserved Core Utilities & Popunder Defenses ---');
assert('SEC-001', 'installNavigationGuard exists and protects against unprompted popunders',
  appJs.includes('installNavigationGuard') && appJs.includes('Blocked unprompted background window.open'));

assert('SEC-002', 'Core PDF/image file validation and download logic is intact',
  appJs.includes('validateSize') && appJs.includes('validateType') && appJs.includes('download('));

console.log('\n================================================================');
console.log(`PRODUCTION AUDIT RESULT: ${passed} PASSED, ${failed} FAILED out of ${passed + failed} TESTS`);
console.log('================================================================\n');

if (failed > 0) process.exit(1);

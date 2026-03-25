// Stealth init script for Patchright MCP.
// Injected via --init-script before any page JavaScript runs.
// Patches headless Chromium fingerprints that cannot be fixed via CLI flags.
//
// Targets: CreepJS, FingerprintJS, BotD, and similar detectors.

(() => {
  "use strict";

  // ─── Configuration ────────────────────────────────────────────────
  // These values should match the chromium service config.
  const SCREEN_WIDTH = 1366;
  const SCREEN_HEIGHT = 768;
  const AVAIL_WIDTH = 1366;
  const AVAIL_HEIGHT = 728; // realistic: taskbar takes ~40px
  const COLOR_DEPTH = 24;
  const PIXEL_DEPTH = 24;
  const DEVICE_PIXEL_RATIO = 1;
  const OUTER_WIDTH = 1366;
  const OUTER_HEIGHT = 744; // slightly less than screen height (title bar + borders)

  // ─── Helpers ──────────────────────────────────────────────────────
  const defineProperty = (obj, prop, value) => {
    Object.defineProperty(obj, prop, {
      get: () => value,
      configurable: true,
      enumerable: true,
    });
  };

  // ─── 0. CSS system colors (hasKnownBgColor) ───────────────────────
  // Headless Chrome resolves the CSS system color "ActiveText" to
  // rgb(255, 0, 0) — pure red.  Real Chrome on Linux with GTK uses
  // a theme color (typically link-blue).  CreepJS creates a div with
  // `background-color: ActiveText`, calls getComputedStyle(), and
  // checks if backgroundColor === "rgb(255, 0, 0)".
  //
  // We inject a global CSS rule that forces ActiveText to a realistic
  // value.  CSS custom property tricks don't work for system colors,
  // but we can use @supports and forced-colors to remap it.
  // Fallback: patch getComputedStyle for the specific red value.
  if (typeof window !== "undefined") {
    const origGetComputedStyle = window.getComputedStyle;
    Object.defineProperty(window, "getComputedStyle", {
      value: function (elt, pseudoElt) {
        const style = origGetComputedStyle.call(this, elt, pseudoElt);
        // Only intercept when the element's inline style uses ActiveText
        if (elt && elt.style && /ActiveText/i.test(elt.style.cssText)) {
          const origBgColor = style.backgroundColor;
          if (origBgColor === "rgb(255, 0, 0)") {
            Object.defineProperty(style, "backgroundColor", {
              value: "rgb(0, 0, 238)",
              configurable: true,
              writable: true,
            });
          }
        }
        return style;
      },
      writable: true,
      configurable: true,
    });
  }

  // ─── 1. Screen dimensions ─────────────────────────────────────────
  // Headless Chromium often reports screen as 0x0 or 1x1.
  // Override to match the configured resolution.
  if (typeof screen !== "undefined") {
    defineProperty(screen, "width", SCREEN_WIDTH);
    defineProperty(screen, "height", SCREEN_HEIGHT);
    defineProperty(screen, "availWidth", AVAIL_WIDTH);
    defineProperty(screen, "availHeight", AVAIL_HEIGHT);
    defineProperty(screen, "colorDepth", COLOR_DEPTH);
    defineProperty(screen, "pixelDepth", PIXEL_DEPTH);
  }

  // ─── 2. Window outer dimensions ───────────────────────────────────
  // In headless mode outerWidth/outerHeight are often 0.
  if (typeof window !== "undefined") {
    defineProperty(window, "outerWidth", OUTER_WIDTH);
    defineProperty(window, "outerHeight", OUTER_HEIGHT);
    defineProperty(window, "devicePixelRatio", DEVICE_PIXEL_RATIO);

    // screenX/screenY — browser window position on screen
    defineProperty(window, "screenX", 0);
    defineProperty(window, "screenY", 0);
    defineProperty(window, "screenLeft", 0);
    defineProperty(window, "screenTop", 0);
  }

  // ─── 3. Permissions API ───────────────────────────────────────────
  // Headless Chrome returns "prompt" for everything. Real browsers
  // return "denied" for notifications by default, etc.
  if (typeof Permissions !== "undefined" && Permissions.prototype.query) {
    const originalQuery = Permissions.prototype.query;
    Permissions.prototype.query = function (desc) {
      // notifications: real Chrome defaults to "denied" unless granted
      if (desc && desc.name === "notifications") {
        return Promise.resolve({ state: "denied", onchange: null });
      }
      return originalQuery.call(this, desc);
    };
  }

  // ─── 4. Navigator patches ─────────────────────────────────────────
  if (typeof navigator !== "undefined") {
    // webdriver: Patchright already patches this, but belt-and-suspenders.
    if (navigator.webdriver === true) {
      defineProperty(navigator, "webdriver", false);
    }

    // plugins — headless often has empty PluginArray.
    // Real Chrome on Linux exposes 5 PDF-related plugins.
    // We create a fake PluginArray if the real one is empty.
    if (navigator.plugins && navigator.plugins.length === 0) {
      const fakePlugins = [
        { name: "PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "Chrome PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "Chromium PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "Microsoft Edge PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "WebKit built-in PDF", filename: "internal-pdf-viewer", description: "Portable Document Format" },
      ];
      const fakePluginArray = {
        length: fakePlugins.length,
        item: (i) => fakePlugins[i] || null,
        namedItem: (name) => fakePlugins.find((p) => p.name === name) || null,
        refresh: () => {},
        [Symbol.iterator]: function* () { for (const p of fakePlugins) yield p; },
      };
      fakePlugins.forEach((p, i) => {
        fakePluginArray[i] = p;
        fakePluginArray[p.name] = p;
      });
      defineProperty(navigator, "plugins", fakePluginArray);

      // mimeTypes — real Chrome exposes 2 PDF mimeTypes
      const fakeMimeTypes = [
        { type: "application/pdf", suffixes: "pdf", description: "Portable Document Format", enabledPlugin: fakePlugins[0] },
        { type: "text/pdf", suffixes: "pdf", description: "Portable Document Format", enabledPlugin: fakePlugins[0] },
      ];
      const fakeMimeTypeArray = {
        length: fakeMimeTypes.length,
        item: (i) => fakeMimeTypes[i] || null,
        namedItem: (type) => fakeMimeTypes.find((m) => m.type === type) || null,
        [Symbol.iterator]: function* () { for (const m of fakeMimeTypes) yield m; },
      };
      fakeMimeTypes.forEach((m, i) => {
        fakeMimeTypeArray[i] = m;
        fakeMimeTypeArray[m.type] = m;
      });
      defineProperty(navigator, "mimeTypes", fakeMimeTypeArray);
    }

    // connection — avoid NetworkInformation fingerprint inconsistencies
    if (navigator.connection) {
      const conn = navigator.connection;
      // Headless sometimes reports rtt=0, downlink=0 (impossible for real user)
      if (conn.rtt === 0) {
        try {
          defineProperty(conn, "rtt", 100);
          defineProperty(conn, "downlink", 2.6);
          defineProperty(conn, "effectiveType", "4g");
        } catch (_) {
          // Some properties may not be configurable
        }
      }
    }
  }

  // ─── 5. Battery API ───────────────────────────────────────────────
  // Headless always reports level=1, charging=true, which is a known
  // fingerprint.  Desktop machines without batteries should reject
  // the promise (like Chrome on desktop Linux does in recent versions).
  // If BatteryStatus disable-feature didn't work, override here.
  if (typeof navigator !== "undefined" && navigator.getBattery) {
    // Option A: make it look like a desktop (reject with NotFoundError)
    // Option B: return realistic values
    // We go with Option A — most Linux desktops don't expose battery API.
    navigator.getBattery = undefined;
    // Also delete from prototype
    try {
      delete Navigator.prototype.getBattery;
    } catch (_) {}
  }

  // ─── 6. ScreenOrientation ─────────────────────────────────────────
  // Ensure orientation matches landscape (consistent with our screen size).
  if (typeof screen !== "undefined" && screen.orientation) {
    try {
      defineProperty(screen.orientation, "type", "landscape-primary");
      defineProperty(screen.orientation, "angle", 0);
    } catch (_) {}
  }

  // ─── 7. matchMedia consistency ────────────────────────────────────
  // Ensure matchMedia queries for device dimensions return consistent results.
  if (typeof window !== "undefined" && window.matchMedia) {
    const origMatchMedia = window.matchMedia.bind(window);
    window.matchMedia = function (query) {
      // Patch prefers-color-scheme to return light (default for most users)
      if (query === "(prefers-color-scheme: dark)") {
        return {
          matches: false,
          media: query,
          onchange: null,
          addListener: () => {},
          removeListener: () => {},
          addEventListener: () => {},
          removeEventListener: () => {},
          dispatchEvent: () => true,
        };
      }
      return origMatchMedia(query);
    };
  }

  // ─── 8. VisualViewport ────────────────────────────────────────────
  // Headless may report incorrect visual viewport dimensions.
  if (typeof window !== "undefined" && window.visualViewport) {
    try {
      defineProperty(window.visualViewport, "width", window.innerWidth || SCREEN_WIDTH);
      defineProperty(window.visualViewport, "height", window.innerHeight || SCREEN_HEIGHT - 139); // ~139px for chrome UI
    } catch (_) {}
  }

  // ─── 9. Chrome runtime object ─────────────────────────────────────
  // Real Chrome exposes window.chrome with specific properties.
  // Headless sometimes has an incomplete chrome object.
  if (typeof window !== "undefined") {
    if (!window.chrome) {
      window.chrome = {};
    }
    if (!window.chrome.runtime) {
      window.chrome.runtime = {
        // PatchRight should handle connect/sendMessage, but ensure object exists.
      };
    }
  }

  // ─── 10. Notification constructor ─────────────────────────────────
  // Real Chrome has Notification.permission === "default" or "denied".
  // Headless sometimes lacks it entirely.
  if (typeof Notification !== "undefined") {
    try {
      defineProperty(Notification, "permission", "default");
    } catch (_) {}
    // Notification.maxActions: headless returns 0, real Chrome returns 2.
    try {
      defineProperty(Notification, "maxActions", 2);
    } catch (_) {}
  }

  // ─── 11. Intl API locale consistency ──────────────────────────────
  // Headless Chromium often returns the system locale (en-US) from Intl
  // APIs even when --lang=ru-RU is set.  This causes a detectable
  // mismatch between navigator.language and Intl.*.resolvedOptions().
  // Patch all Intl formatters to default to navigator.language.
  if (typeof Intl !== "undefined" && typeof navigator !== "undefined") {
    const targetLocale = navigator.language || "ru-RU";
    const patchIntlConstructor = (Ctor) => {
      if (!Ctor) return;
      const Original = Ctor;
      const Patched = function (locales, options) {
        if (locales === undefined || locales === null) {
          locales = targetLocale;
        }
        if (new.target) {
          return new Original(locales, options);
        }
        return Original(locales, options);
      };
      Patched.prototype = Original.prototype;
      Patched.supportedLocalesOf = Original.supportedLocalesOf;
      Object.setPrototypeOf(Patched, Original);
      return Patched;
    };
    try { Intl.DateTimeFormat = patchIntlConstructor(Intl.DateTimeFormat); } catch (_) {}
    try { Intl.NumberFormat = patchIntlConstructor(Intl.NumberFormat); } catch (_) {}
    try { Intl.Collator = patchIntlConstructor(Intl.Collator); } catch (_) {}
    try { Intl.PluralRules = patchIntlConstructor(Intl.PluralRules); } catch (_) {}
    try { Intl.RelativeTimeFormat = patchIntlConstructor(Intl.RelativeTimeFormat); } catch (_) {}
    try { Intl.ListFormat = patchIntlConstructor(Intl.ListFormat); } catch (_) {}
    try { Intl.DisplayNames = patchIntlConstructor(Intl.DisplayNames); } catch (_) {}
    try { Intl.Segmenter = patchIntlConstructor(Intl.Segmenter); } catch (_) {}
  }

  // ─── 12. Speech synthesis voices ──────────────────────────────────
  // Headless Chrome has no speech synthesis voices, which detectors flag.
  // Inject a realistic set of voices matching Chrome on Linux with
  // speech-dispatcher.  IMPORTANT: CreepJS on Blink requires at least
  // one voice with localService=true, otherwise it times out and
  // reports "blocked".  Local voices come from speech-dispatcher;
  // remote voices are the Google cloud TTS voices Chrome adds.
  if (typeof window !== "undefined" && window.speechSynthesis) {
    const fakeVoices = [
      // Local voices (speech-dispatcher on Linux)
      { name: "English (United States)", lang: "en-US", localService: true, default: true, voiceURI: "English (United States)" },
      { name: "Russian (Russia)", lang: "ru-RU", localService: true, default: false, voiceURI: "Russian (Russia)" },
      // Remote voices (Google cloud TTS)
      { name: "Google US English", lang: "en-US", localService: false, default: false, voiceURI: "Google US English" },
      { name: "Google UK English Female", lang: "en-GB", localService: false, default: false, voiceURI: "Google UK English Female" },
      { name: "Google UK English Male", lang: "en-GB", localService: false, default: false, voiceURI: "Google UK English Male" },
      { name: "Google русский", lang: "ru-RU", localService: false, default: false, voiceURI: "Google русский" },
      { name: "Google Deutsch", lang: "de-DE", localService: false, default: false, voiceURI: "Google Deutsch" },
      { name: "Google español", lang: "es-ES", localService: false, default: false, voiceURI: "Google español" },
      { name: "Google français", lang: "fr-FR", localService: false, default: false, voiceURI: "Google français" },
      { name: "Google italiano", lang: "it-IT", localService: false, default: false, voiceURI: "Google italiano" },
      { name: "Google 日本語", lang: "ja-JP", localService: false, default: false, voiceURI: "Google 日本語" },
      { name: "Google 한국의", lang: "ko-KR", localService: false, default: false, voiceURI: "Google 한국의" },
      { name: "Google 中文（简体）", lang: "zh-CN", localService: false, default: false, voiceURI: "Google 中文（简体）" },
    ];
    const origGetVoices = window.speechSynthesis.getVoices.bind(window.speechSynthesis);
    window.speechSynthesis.getVoices = function () {
      const voices = origGetVoices();
      return voices.length > 0 ? voices : fakeVoices;
    };
    // Trigger voiceschanged after a short delay so pages that listen
    // for it (including CreepJS) pick up the voices reliably.
    try {
      setTimeout(() => {
        try { window.speechSynthesis.dispatchEvent(new Event("voiceschanged")); } catch (_) {}
      }, 10);
    } catch (_) {}
  }

  // ─── 13. chrome.app — real Chrome exposes a chrome.app object ─────
  if (typeof window !== "undefined" && window.chrome) {
    if (!window.chrome.app) {
      window.chrome.app = {
        isInstalled: false,
        InstallState: { DISABLED: "disabled", INSTALLED: "installed", NOT_INSTALLED: "not_installed" },
        RunningState: { CANNOT_RUN: "cannot_run", READY_TO_RUN: "ready_to_run", RUNNING: "running" },
        getDetails: () => null,
        getIsInstalled: () => false,
        installState: (cb) => cb && cb("not_installed"),
        runningState: () => "cannot_run",
      };
    }
    // chrome.csi and chrome.loadTimes — legacy but still checked
    if (!window.chrome.csi) {
      window.chrome.csi = () => ({
        startE: Date.now(),
        onloadT: Date.now(),
        pageT: performance.now(),
        tran: 15,
      });
    }
    if (!window.chrome.loadTimes) {
      window.chrome.loadTimes = () => ({
        commitLoadTime: Date.now() / 1000,
        connectionInfo: "h2",
        finishDocumentLoadTime: Date.now() / 1000,
        finishLoadTime: Date.now() / 1000,
        firstPaintAfterLoadTime: 0,
        firstPaintTime: Date.now() / 1000,
        navigationType: "Other",
        npnNegotiatedProtocol: "h2",
        requestTime: Date.now() / 1000 - 0.3,
        startLoadTime: Date.now() / 1000 - 0.5,
        wasAlternateProtocolAvailable: false,
        wasFetchedViaSpdy: true,
        wasNpnNegotiated: true,
      });
    }
  }

  // ─── 14. WebGL debug renderer info consistency ────────────────────
  // Some detectors check for the WEBGL_debug_renderer_info extension
  // being present but returning empty strings (headless artifact).
  // We don't override actual values here — just ensure the extension
  // is not blocked or returning anomalous data.

  // ─── 15. Hardware concurrency & device memory ─────────────────────
  // Headless sometimes reports unusual values. Ensure they match
  // realistic desktop hardware.
  if (typeof navigator !== "undefined") {
    if (navigator.hardwareConcurrency === 0 || navigator.hardwareConcurrency === undefined) {
      defineProperty(navigator, "hardwareConcurrency", 4);
    }
    if (navigator.deviceMemory === 0 || navigator.deviceMemory === undefined) {
      defineProperty(navigator, "deviceMemory", 8);
    }
  }

  // ─── 16. Web Share API (noWebShare) ───────────────────────────────
  // CreepJS flags `noWebShare` when navigator.share/canShare are missing
  // on Blink with accent-color support (Chrome 93+).  Desktop Linux
  // Chrome genuinely lacks Web Share, so this is a false positive, but
  // adding stubs lowers the headless score.  The stubs reject with
  // NotAllowedError (same as Chrome on unsupported platforms).
  if (typeof navigator !== "undefined") {
    if (!navigator.share) {
      navigator.share = function () {
        return Promise.reject(new DOMException("Share canceled", "NotAllowedError"));
      };
    }
    if (!navigator.canShare) {
      navigator.canShare = function () { return false; };
    }
  }
})();

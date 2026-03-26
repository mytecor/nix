// Stealth init-script for Patchright MCP.
// Injected before any page script via --init-script.
// Patches headless fingerprint signals detected by CreepJS.

(() => {
  'use strict';

  // ---- Helper: define a non-enumerable, configurable property ----------
  const defineProp = (obj, prop, descriptor) => {
    Object.defineProperty(obj, prop, { configurable: true, ...descriptor });
  };

  // ---- 1. hasKnownBgColor ------------------------------------------------
  // CreepJS creates a div with `background-color: ActiveText` and checks
  // whether getComputedStyle returns `rgb(255, 0, 0)` — the hardcoded
  // headless Chromium value for the CSS system color keyword `ActiveText`.
  // On a real Linux desktop (e.g. GNOME/Adwaita) `ActiveText` is typically
  // something like `rgb(53, 132, 228)`.
  //
  // CSS `@color-profile` / `color-scheme` cannot override system colors
  // directly, so we intercept getComputedStyle to rewrite the value.
  try {
    const _getComputedStyle = window.getComputedStyle;
    const HEADLESS_ACTIVE_TEXT = 'rgb(255, 0, 0)';
    const REAL_ACTIVE_TEXT     = 'rgb(53, 132, 228)'; // GNOME Adwaita

    window.getComputedStyle = function (elt, pseudoElt) {
      const cs = _getComputedStyle.call(this, elt, pseudoElt);
      // Only patch if the element's inline style uses the ActiveText keyword
      const inlineStyle = elt?.style?.backgroundColor;
      if (inlineStyle && /ActiveText/i.test(inlineStyle)) {
        return new Proxy(cs, {
          get(target, prop, receiver) {
            if (prop === 'backgroundColor') {
              const val = target.backgroundColor;
              return val === HEADLESS_ACTIVE_TEXT ? REAL_ACTIVE_TEXT : val;
            }
            const v = Reflect.get(target, prop, receiver);
            return typeof v === 'function' ? v.bind(target) : v;
          },
        });
      }
      return cs;
    };
  } catch (_) { /* non-window context */ }

  // ---- 2. prefersLightColor -----------------------------------------------
  // In headless Chromium `prefers-color-scheme` is `light` by default, which
  // is actually the *correct* value for a normal desktop.  However the check
  // only flags it when combined with other headless signals.  No override
  // needed — this resolves naturally once the other flags are fixed.
  // (Keeping this comment for documentation.)

  // ---- 3. noWebShare -------------------------------------------------------
  // CreepJS: `!('share' in navigator) || !('canShare' in navigator)`
  // Web Share API is absent in headless Linux Chrome.  Stub it.
  if (!('share' in navigator)) {
    defineProp(navigator, 'share', {
      value: function share(data) {
        return Promise.reject(new DOMException(
          'Share canceled', 'AbortError'
        ));
      },
      writable: true,
      enumerable: true,
    });
  }
  if (!('canShare' in navigator)) {
    defineProp(navigator, 'canShare', {
      value: function canShare(data) {
        return false;
      },
      writable: true,
      enumerable: true,
    });
  }

  // ---- 4. noContentIndex ---------------------------------------------------
  // CreepJS: `!('ContentIndex' in window)`
  // Content Index API is Android-only; absent on desktop Linux.
  // On Android Chrome it exists, so for a Linux fingerprint this check
  // is expected to be absent.  However CreepJS flags it as headless on
  // Linux too if the Chrome version is >= 84.  Stub the class.
  if (!('ContentIndex' in window)) {
    window.ContentIndex = class ContentIndex {
      async add() { throw new DOMException('Not allowed', 'InvalidAccessError'); }
      async delete() {}
      async getAll() { return []; }
    };
  }

  // ---- 5. noContactsManager ------------------------------------------------
  // CreepJS: `!('ContactsManager' in window)`
  // Same situation as ContentIndex — Android-only but flagged on Linux.
  if (!('ContactsManager' in window)) {
    window.ContactsManager = class ContactsManager {
      async getProperties() { return ['name', 'email', 'tel']; }
      async select() { return []; }
    };
  }

  // ---- 6. noDownlinkMax ----------------------------------------------------
  // CreepJS: `!('downlinkMax' in (window.NetworkInformation?.prototype || {}))`
  // On Linux Chrome, NetworkInformation.prototype lacks `downlinkMax`
  // (it's only present on Android).  Add it.
  try {
    const niProto = Object.getPrototypeOf(navigator.connection);
    if (niProto && !('downlinkMax' in niProto)) {
      defineProp(niProto, 'downlinkMax', {
        get() {
          // Infinity means "unknown upper bound" — the spec default for
          // wired / Wi-Fi connections.
          return Infinity;
        },
        enumerable: true,
      });
    }
  } catch (_) { /* navigator.connection may not exist */ }

  // ---- 7. Screen / Viewport consistency ------------------------------------
  // noTaskbar:      `screen.height === screen.availHeight`
  // hasVvpScreenRes: `innerWidth === screen.width && outerHeight === screen.height`
  //                  OR `visualViewport.width === screen.width`
  //
  // In headless mode the window fills the entire virtual screen, so
  // screen.availHeight === screen.height (no taskbar) and the viewport
  // matches the screen exactly.
  //
  // Fix: spoof screen.availHeight/availWidth to simulate a taskbar.
  // The Chromium module sets --window-size to be smaller than
  // --ozone-override-screen-size, so outerHeight < screen.height.
  // But screen.availHeight still equals screen.height in headless,
  // so we patch it here to match the window size (screen minus taskbar).
  const TASKBAR_HEIGHT = 40; // typical Linux DE taskbar

  try {
    const realWidth = screen.width;
    const realHeight = screen.height;
    const availH = realHeight - TASKBAR_HEIGHT;

    // Only patch if avail === full (headless symptom)
    if (screen.availHeight === realHeight) {
      defineProp(Screen.prototype, 'availHeight', {
        get() { return availH; },
        enumerable: true,
      });
    }
    // availWidth stays the same (taskbar is horizontal, at the bottom)
  } catch (_) {}
})();

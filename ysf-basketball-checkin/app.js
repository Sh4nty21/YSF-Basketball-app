/* ═══════════════════════════════════════════════════════════════════════════
   Module B — behaviour.

   Responsibilities (spec Section 3): read the session id out of the QR URL,
   validate the three fields client-side for a fast reply, POST to the backend,
   and show the result. It knows nothing about teams, balancing, or the
   database — the backend re-validates everything it receives.
   ═══════════════════════════════════════════════════════════════════════════ */

(function () {
  "use strict";

  var CONFIG = window.YSF_CONFIG || {};
  var MIN_AGE = 13;
  var MAX_AGE = 22;

  /* ── API base ──────────────────────────────────────────────────────────
     Empty config -> assume the backend serves this page (it mounts the form
     at /checkin), so the API lives at <origin>/api/v1. */
  function apiBase() {
    var configured = (CONFIG.apiBaseUrl || "").trim();
    if (configured) return configured.replace(/\/+$/, "");
    return window.location.origin + "/api/v1";
  }

  /* ── Device id ─────────────────────────────────────────────────────────
     A random id persisted in this browser so the backend can cap how many
     people the same device checks in per session (anti-flooding). Not tied
     to any personal identity — just this browser's local storage. Falls
     back to an in-memory id if storage is unavailable (private mode, etc.),
     which simply means the cap resets on reload in that edge case. */
  var DEVICE_ID_KEY = "ysf_device_id";

  function randomId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      return window.crypto.randomUUID();
    }
    return "dev-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2);
  }

  function deviceId() {
    try {
      var existing = window.localStorage.getItem(DEVICE_ID_KEY);
      if (existing) return existing;
      var created = randomId();
      window.localStorage.setItem(DEVICE_ID_KEY, created);
      return created;
    } catch (_) {
      // localStorage blocked — fall back to a per-page-load id.
      if (!deviceId._fallback) deviceId._fallback = randomId();
      return deviceId._fallback;
    }
  }

  /* ── Element lookup ────────────────────────────────────────────────── */
  var el = {
    form: document.getElementById("checkinForm"),
    noSession: document.getElementById("noSessionCard"),
    success: document.getElementById("successCard"),
    name: document.getElementById("name"),
    age: document.getElementById("age"),
    submit: document.getElementById("submitBtn"),
    nameError: document.getElementById("nameError"),
    ageError: document.getElementById("ageError"),
    sportBadge: document.getElementById("sportBadge"),
    skillField: document.getElementById("skillField"),
    skillError: document.getElementById("skillError"),
    positionField: document.getElementById("positionField"),
    positionError: document.getElementById("positionError"),
    formError: document.getElementById("formError"),
    successTitle: document.getElementById("successTitle"),
    successBody: document.getElementById("successBody"),
    another: document.getElementById("anotherBtn"),
    subhead: document.getElementById("sessionSubhead"),
    footerBrand: document.getElementById("footerBrand"),
    sessionTag: document.getElementById("sessionTag"),
  };

  /* ── Sport-conditional field: volleyball collects a position instead of
     a skill level (skill isn't used for volleyball team generation at all).
     Defaults to the skill-level field showing, matching every sport except
     volleyball, so a failed /checkin-info fetch degrades to today's
     behaviour rather than breaking the form. ───────────────────────────── */
  var sessionSport = null; // set once /checkin-info resolves

  /* ── Session id from the QR URL: ?session=12 ───────────────────────── */
  function readSessionId() {
    var params = new URLSearchParams(window.location.search);
    var raw = params.get("session");
    if (raw === null) {
      // Some address bars / share sheets mangle query-string casing (e.g.
      // Caps Lock while typing during local testing) — URLSearchParams.get
      // is case-sensitive, so fall back to a case-insensitive scan rather
      // than incorrectly treating a real session link as missing.
      for (var pair of params.entries()) {
        if (pair[0].toLowerCase() === "session") {
          raw = pair[1];
          break;
        }
      }
    }
    if (raw === null || raw === undefined) return null;
    var value = parseInt(raw, 10);
    return Number.isInteger(value) && value > 0 ? value : null;
  }

  var sessionId = readSessionId();

  /* ── Small view helpers ────────────────────────────────────────────── */
  function show(node) { if (node) node.hidden = false; }
  function hide(node) { if (node) node.hidden = true; }

  function setError(node, input, message) {
    if (message) {
      node.textContent = message;
      node.hidden = false;
      if (input) input.setAttribute("aria-invalid", "true");
    } else {
      node.textContent = "";
      node.hidden = true;
      if (input) input.removeAttribute("aria-invalid");
    }
  }

  function clearErrors() {
    setError(el.nameError, el.name, "");
    setError(el.ageError, el.age, "");
    setError(el.skillError, null, "");
    setError(el.positionError, null, "");
    setError(el.formError, null, "");
  }

  function setLoading(isLoading) {
    el.submit.disabled = isLoading;
    el.submit.classList.toggle("is-loading", isLoading);
    el.submit.querySelector(".btn-label").textContent = isLoading
      ? "Checking you in…"
      : "I'm here — check me in";
  }

  function selectedSkill() {
    var checked = el.form.querySelector('input[name="skill_level"]:checked');
    return checked ? checked.value : "";
  }

  function selectedPosition() {
    var checked = el.form.querySelector('input[name="position"]:checked');
    return checked ? checked.value : "";
  }

  function isVolleyball() {
    return sessionSport === "volleyball";
  }

  var SPORT_LABELS = {
    basketball: "Basketball",
    volleyball: "Volleyball",
    badminton: "Badminton"
  };

  /* Shows a label naming this session's actual sport — stays hidden if the
     sport is unknown (e.g. /checkin-info failed) rather than ever risk
     showing the wrong one. */
  function applySportBadge() {
    if (!el.sportBadge) return;
    var label = SPORT_LABELS[sessionSport];
    if (!label) {
      hide(el.sportBadge);
      return;
    }
    el.sportBadge.textContent = label;
    el.sportBadge.className = "sport-badge sport-badge--" + sessionSport;
    show(el.sportBadge);
  }

  /* ── Client-side validation (the backend enforces the same rules) ──── */
  function validate() {
    clearErrors();
    var ok = true;

    var name = el.name.value.replace(/\s+/g, " ").trim();
    if (!name) {
      setError(el.nameError, el.name, "Please type your name.");
      ok = false;
    } else if (name.length > 100) {
      setError(el.nameError, el.name, "That name is too long.");
      ok = false;
    }

    var ageText = el.age.value.trim();
    var age = parseInt(ageText, 10);
    if (!ageText) {
      setError(el.ageError, el.age, "Please enter your age.");
      ok = false;
    } else if (!/^\d+$/.test(ageText) || Number.isNaN(age)) {
      setError(el.ageError, el.age, "Age has to be a number.");
      ok = false;
    } else if (age < MIN_AGE || age > MAX_AGE) {
      setError(el.ageError, el.age, "Age must be between " + MIN_AGE + " and " + MAX_AGE + ".");
      ok = false;
    }

    var payload = { name: name, age: age, device_id: deviceId() };

    if (isVolleyball()) {
      if (!selectedPosition()) {
        setError(el.positionError, null, "Pick your position.");
        ok = false;
      } else {
        payload.position = selectedPosition();
      }
    } else {
      if (!selectedSkill()) {
        setError(el.skillError, null, "Pick one skill level.");
        ok = false;
      } else {
        payload.skill_level = selectedSkill();
      }
    }

    return ok ? payload : null;
  }

  /* ── Show the field this session's sport actually needs, and the label
     naming it ──────────────────────────────────────────────────────────── */
  function applySportFields() {
    if (isVolleyball()) {
      hide(el.skillField);
      show(el.positionField);
    } else {
      show(el.skillField);
      hide(el.positionField);
    }
    applySportBadge();
  }

  /* ── Learn this session's sport before the form is usable — public,
     reveals nothing beyond sport/status (app/routers/checkin.py). A failed
     fetch (offline, old cached page) just leaves the default skill-level
     field showing, same as before this existed. ───────────────────────── */
  async function loadSessionSport() {
    try {
      var response = await fetch(apiBase() + "/sessions/" + sessionId + "/checkin-info");
      if (!response.ok) return;
      var body = await response.json();
      sessionSport = body && body.sport ? body.sport : null;
    } catch (_) {
      // Network failure — keep the default (non-volleyball) fields showing.
    } finally {
      applySportFields();
    }
  }

  /* ── Turn a failed response into something a teenager can act on ───── */
  function friendlyError(status, payload) {
    if (status === 404) {
      return "That session doesn't exist any more. Please re-scan the QR code or ask an organizer.";
    }
    if (status === 409) {
      return (payload && payload.detail) || "Check-in for this session is closed.";
    }
    if (status === 429) {
      return (payload && payload.detail) ||
        "This device has already checked in the maximum number of people for this session. See an organizer if you need to add more.";
    }
    if (status === 422) {
      var detail = payload && payload.detail;
      if (Array.isArray(detail) && detail.length) {
        var first = detail[0];
        var field = Array.isArray(first.loc) ? first.loc[first.loc.length - 1] : "input";
        return "Please check the " + field + " field: " + first.msg;
      }
      return "Some details look off. Please check the form and try again.";
    }
    if (status >= 500) {
      return "The check-in server hit a problem. Please tell an organizer.";
    }
    return (payload && payload.detail) || "Something went wrong. Please try again.";
  }

  /* ── Submit ────────────────────────────────────────────────────────── */
  async function handleSubmit(event) {
    event.preventDefault();

    var payload = validate();
    if (!payload) {
      var firstError = el.form.querySelector('[aria-invalid="true"], .error:not([hidden])');
      if (firstError && firstError.scrollIntoView) {
        firstError.scrollIntoView({ behavior: "smooth", block: "center" });
      }
      return;
    }

    setLoading(true);

    try {
      var response = await fetch(apiBase() + "/sessions/" + sessionId + "/checkin", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(payload),
      });

      var body = null;
      try { body = await response.json(); } catch (_) { /* empty or non-JSON body */ }

      if (!response.ok) {
        setError(el.formError, null, friendlyError(response.status, body));
        setLoading(false);
        return;
      }

      el.successTitle.textContent = "You're in, " + payload.name.split(" ")[0] + "!";
      el.successBody.textContent = (body && body.message) || "See you on the court.";
      // Clear the fields before hiding, so the next person (or a re-shown
      // form) never sees the previous participant's details and can't be
      // double-submitted by mistake.
      el.form.reset();
      clearErrors();
      hide(el.form);
      show(el.success);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (networkError) {
      // fetch() only rejects on network-level failures.
      setError(
        el.formError,
        null,
        "Can't reach the check-in server. Check your internet connection and try again."
      );
    } finally {
      setLoading(false);
    }
  }

  /* ── "Check in someone else" — for shared phones and siblings ───────── */
  function resetForm() {
    el.form.reset();
    clearErrors();
    hide(el.success);
    show(el.form);
    el.name.focus();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  /* ── Boot ──────────────────────────────────────────────────────────── */
  function init() {
    if (CONFIG.programName) el.footerBrand.textContent = CONFIG.programName;
    if (CONFIG.tagline) el.subhead.textContent = CONFIG.tagline;

    if (sessionId === null) {
      show(el.noSession);
      el.sessionTag.textContent = "No session";
      return;
    }

    el.sessionTag.textContent = "Session #" + sessionId;
    show(el.form);
    el.form.addEventListener("submit", handleSubmit);
    el.another.addEventListener("click", resetForm);

    // Clear a field's error as soon as the participant starts fixing it.
    el.name.addEventListener("input", function () { setError(el.nameError, el.name, ""); });
    el.age.addEventListener("input", function () { setError(el.ageError, el.age, ""); });
    el.form.querySelectorAll('input[name="skill_level"]').forEach(function (radio) {
      radio.addEventListener("change", function () { setError(el.skillError, null, ""); });
    });
    el.form.querySelectorAll('input[name="position"]').forEach(function (radio) {
      radio.addEventListener("change", function () { setError(el.positionError, null, ""); });
    });

    // Learn this session's sport (async) before deciding skill vs. position —
    // starts with the skill field showing, swapped out if this turns out to
    // be a volleyball session.
    loadSessionSport();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

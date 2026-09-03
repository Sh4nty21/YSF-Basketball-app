/**
 * Module B — configuration.
 *
 * This is the ONLY file you need to edit when the backend moves.
 *
 * apiBaseUrl:
 *   ""  (empty)  -> auto-detect. Uses the same origin the page is served from.
 *                   Correct when the backend serves this page at /checkin,
 *                   which is how the deployed setup works.
 *   "http://localhost:8000/api/v1"                 -> local testing
 *   "https://ysf-basketball-api.onrender.com/api/v1" -> deployed backend
 *
 * Nothing secret belongs in here: this file is downloaded by every phone that
 * scans the QR code.
 */
window.YSF_CONFIG = {
  apiBaseUrl: "",

  // Shown on the confirmation screen.
  programName: "Elevate YSF",
  tagline: "Weekly Sports Fellowship",
};

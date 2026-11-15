// Page-level browser calls for browser.gleam and route.gleam: the version
// stamped into the page, the service worker, the clock. No decisions here;
// Gleam makes them.
import { Result$Ok, Result$Error } from "../gleam.mjs";

export function running_version() {
  return document.querySelector('meta[name="app-version"]').content;
}

export function running_commit() {
  return document.querySelector('meta[name="app-commit"]').content;
}

export function page_path() {
  return location.pathname;
}

export function fetch_no_store(url) {
  return fetch(url, { cache: "no-store" }).then(
    async (response) => Result$Ok(await response.text()),
    (error) => Result$Error(String(error)),
  );
}

export function register_worker(url) {
  navigator.serviceWorker?.register(url);
}

export function on_visibility_change(callback) {
  document.addEventListener("visibilitychange", () => callback(document.visibilityState));
}

export function on_controller_change(callback) {
  navigator.serviceWorker?.addEventListener("controllerchange", () => callback());
}

// Fetch the newest worker and tell it to take over. False when there is no
// new worker to tell (or no service worker at all).
export async function activate_new_worker() {
  try {
    const registration = await navigator.serviceWorker.getRegistration();
    await registration.update();
    (registration.waiting ?? registration.installing).postMessage("skip-waiting");
    return true;
  } catch {
    return false;
  }
}

export function reload() {
  location.reload();
}

export function now_ms() {
  return Date.now();
}

export function local_time(ms) {
  return new Date(ms).toLocaleString();
}

export function current_hash() {
  return location.hash;
}

export function on_hash_change(callback) {
  window.addEventListener("hashchange", () => callback(location.hash));
}

export function scroll_y() {
  return window.scrollY;
}

export function scroll_to(y) {
  window.scrollTo(0, y);
}

export function manual_scroll_restoration() {
  history.scrollRestoration = "manual";
}

export function random_id() {
  return crypto.randomUUID();
}

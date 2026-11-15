// IndexedDB calls for storage.gleam. Every function resolves to a Gleam
// Result and never rejects. Values are the JSON strings Gleam made.
import { Result$Ok, Result$Error } from "../gleam.mjs";

async function attempt(run, describe = String) {
  try {
    return await run();
  } catch (error) {
    return Result$Error(describe(error));
  }
}

// The error's name and its words, so Gleam can tell one failure from another.
const nameAndWords = (error) => [error?.name ?? "", String(error)];

export function open(name, version, storesToCreate) {
  return attempt(() => new Promise((resolve) => {
    const request = indexedDB.open(name, version);
    request.onupgradeneeded = (event) => {
      for (const store of storesToCreate(event.oldVersion)) request.result.createObjectStore(store);
    };
    request.onsuccess = () => {
      // Close when a newer tab asks to upgrade the schema, so it is not blocked.
      request.result.onversionchange = () => request.result.close();
      resolve(Result$Ok(request.result));
    };
    request.onerror = () => resolve(Result$Error(nameAndWords(request.error)));
  }), nameAndWords);
}

export function get(db, store, key) {
  return attempt(() => new Promise((resolve) => {
    const request = db.transaction(store, "readonly").objectStore(store).get(key);
    request.onsuccess = () => resolve(Result$Ok(request.result));
    request.onerror = () => resolve(Result$Error(String(request.error)));
  }));
}

// One transaction: removes, then puts. All are committed or none.
export function write(db, stores, puts, removes) {
  return attempt(() => new Promise((resolve) => {
    const transaction = db.transaction([...stores], "readwrite");
    transaction.oncomplete = () => resolve(Result$Ok(undefined));
    transaction.onerror = transaction.onabort = () => resolve(Result$Error(String(transaction.error)));
    try {
      for (const [store, key] of removes) transaction.objectStore(store).delete(key);
      for (const [store, key, value] of puts) transaction.objectStore(store).put(value, key);
    } catch (error) {
      transaction.abort();
      throw error;
    }
  }));
}

// Resolves to [keys, values]: two arrays in the same key order.
export function get_all(db, store) {
  return attempt(() => new Promise((resolve) => {
    const objects = db.transaction(store, "readonly").objectStore(store);
    const keys = objects.getAllKeys();
    const values = objects.getAll();
    values.onsuccess = () => resolve(Result$Ok([keys.result, values.result]));
    keys.onerror = () => resolve(Result$Error(String(keys.error)));
    values.onerror = () => resolve(Result$Error(String(values.error)));
  }));
}

export function persist() {
  return attempt(async () => Result$Ok(await navigator.storage.persist()));
}

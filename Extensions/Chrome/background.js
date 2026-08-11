const HOST_NAME = "io.github.rchatham.linkcompass";
const pendingNotifications = new Map();
const recentChecks = new Map();
const CHECK_DEBOUNCE_MS = 10000;

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status !== "complete" || !tab.url) {
    return;
  }

  const originURL = httpOriginURL(tab.url);
  if (!originURL) {
    return;
  }

  const checkKey = `${tabId}:${originURL}`;
  const lastCheckedAt = recentChecks.get(checkKey) || 0;
  if (Date.now() - lastCheckedAt < CHECK_DEBOUNCE_MS) {
    return;
  }
  recentChecks.set(checkKey, Date.now());

  chrome.runtime.sendNativeMessage(
    HOST_NAME,
    { type: "recentRouteForURL", url: originURL },
    (response) => handleRecentRouteResponse(tabId, response)
  );
});

chrome.notifications.onButtonClicked.addListener((notificationId, buttonIndex) => {
  const route = pendingNotifications.get(notificationId);
  if (!route) {
    return;
  }
  pendingNotifications.delete(notificationId);
  chrome.notifications.clear(notificationId);

  if (buttonIndex !== 0) {
    return;
  }

  chrome.runtime.sendNativeMessage(
    HOST_NAME,
    {
      type: "rememberRoute",
      host: route.host,
      browserBundleIdentifier: route.browserBundleIdentifier
    },
    (response) => {
      if (!response || response.ok !== true) {
        const message = response?.error || chrome.runtime.lastError?.message || "Unknown error";
        showStatusNotification("LinkCompass could not save this route", message);
        return;
      }
      showStatusNotification("LinkCompass route saved", `${route.host} will open in ${route.browserDisplayName}.`);
    }
  );
});

chrome.notifications.onClosed.addListener((notificationId) => {
  pendingNotifications.delete(notificationId);
});

chrome.tabs.onRemoved.addListener((tabId) => {
  const prefix = `${tabId}:`;
  for (const key of recentChecks.keys()) {
    if (key.startsWith(prefix)) {
      recentChecks.delete(key);
    }
  }
});

function handleRecentRouteResponse(tabId, response) {
  if (chrome.runtime.lastError) {
    return;
  }
  if (!response || response.ok !== true || response.matched !== true) {
    return;
  }

  const route = {
    host: response.host,
    browserBundleIdentifier: response.browserBundleIdentifier,
    browserDisplayName: response.browserDisplayName || "this browser"
  };

  if (!route.host || !route.browserBundleIdentifier) {
    return;
  }

  const notificationId = `linkcompass-${tabId}-${Date.now()}`;
  pendingNotifications.set(notificationId, route);
  chrome.notifications.create(notificationId, {
    type: "basic",
    iconUrl: "icons/icon128.png",
    title: "Remember this LinkCompass route?",
    message: `Always open ${route.host} in ${route.browserDisplayName}?`,
    buttons: [
      { title: "Remember" },
      { title: "Not now" }
    ],
    priority: 1
  });
}

function showStatusNotification(title, message) {
  chrome.notifications.create({
    type: "basic",
    iconUrl: "icons/icon128.png",
    title,
    message,
    priority: 0
  });
}

function httpOriginURL(rawURL) {
  try {
    const url = new URL(rawURL);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return null;
    }
    return url.origin;
  } catch {
    return null;
  }
}

/* global log, query */

const observe = activeInfo => chrome.tabs.get(activeInfo.tabId, tab => query({
  windowId: activeInfo.windowId,
  index: tab.index + 1,
  discarded: true
}).then(tbs => {
  if (tbs.length) {
    log('release discarding of the next tab', tbs[0]);
    chrome.tabs.reload(tbs[0].id);
  }
}));

function enable() {
  log('next.enable is called');
  chrome.tabs.onActivated.addListener(observe);
  query({
    active: true,
    currentWindow: true
  }).then(tbs => {
    if (tbs.length) {
      observe({
        tabId: tbs[0].id
      });
    }
  });
}
function disable() {
  log('next.disable is called');
  chrome.tabs.onActivated.removeListener(observe);
}

export {
  enable,
  disable
};

// Local-only recommendation. No network, storage or fingerprint collection.
// Every platform remains visible; never auto-download or claim exact CPU support.
(() => {
  const ua = navigator.userAgent;
  const ios = /iPhone|iPad|iPod/i.test(ua) || (/Macintosh/i.test(ua) && navigator.maxTouchPoints > 1);
  const platform = /Android/i.test(ua) ? 'android' : /Windows/i.test(ua) ? 'windows' : !ios && /Macintosh|Mac OS X/i.test(ua) ? 'mac' : null;
  const hint = document.querySelector('#platform-hint');
  if (platform) {
    const card = document.querySelector(`[data-platform="${platform}"]`);
    card.classList.add('recommended');
    const badge = document.createElement('span'); badge.className = 'recommendation'; badge.textContent = 'For your system';
    card.prepend(badge);
    const names = { android: 'Android', windows: 'Windows', mac: 'macOS' };
    hint.textContent = `Your browser appears to use ${names[platform]}. Check the version and processor requirements below; all downloads remain available.`;
  } else if (ios) {
    hint.textContent = 'You appear to be on iPhone or iPad. There is no iOS build yet; the Android APK will not install on iOS. You can still download for another device.';
  }
})();

/* global $ */
(function () {
  function isMonitorPage() {
    const path = (window.location.pathname || '').toLowerCase();
    return path.indexOf('module-monitor-active-calls') !== -1
      || path.indexOf('modulemonitoractivecalls') !== -1
      || document.getElementById('app-queue') != null
      || document.getElementById('calls') != null;
  }

  function apply() {
    if (!isMonitorPage()) return;
    document.body.classList.add('ss-monitor-route');
    // Remove vendor logo if still rendered by an unpatched header
    document.querySelectorAll('img.ui.tiny.right.floated.image').forEach((img) => {
      const src = img.getAttribute('src') || '';
      if (src.indexOf('ModuleMonitorActiveCalls') !== -1 || src.indexOf('logo.svg') !== -1) {
        img.remove();
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', apply);
  } else {
    apply();
  }
  // Module content may paint after Vue boots
  setTimeout(apply, 300);
  setTimeout(apply, 1200);
}());

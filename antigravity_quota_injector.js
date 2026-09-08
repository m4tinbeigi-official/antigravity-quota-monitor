(() => {
  // Clean up any legacy floating pills or popovers
  document.getElementById('antigravity-usage-pill')?.remove();
  document.getElementById('antigravity-usage-popover')?.remove();

  let currentUsage = {
    session: {
      used_pct: 0,
      resets_in: "N/A"
    },
    weekly: {
      used_pct: 0,
      resets_in: "Sunday"
    }
  };

  function isDarkTheme() {
    return document.body.classList.contains('dark') ||
           document.body.classList.contains('theme-dark') ||
           document.documentElement.classList.contains('dark') ||
           (window.getComputedStyle(document.body).backgroundColor.includes('16, 16, 16'));
  }

  async function fetchStoredQuota() {
    try {
      if (window.nativeStorage) {
        const items = await window.nativeStorage.getItems();
        if (items && items['antigravity:active_quota']) {
          const parsed = JSON.parse(items['antigravity:active_quota']);
          if (parsed && parsed.session) {
            currentUsage = parsed;
          }
        }
      }
    } catch (e) {}
  }

  function applyThemeStyles(badge) {
    const dark = isDarkTheme();
    badge.style.display = 'inline-flex';
    badge.style.alignItems = 'center';
    badge.style.gap = '4px';
    badge.style.marginLeft = '4px';
    badge.style.marginRight = '2px';
    badge.style.padding = '1.5px 7px';
    badge.style.borderRadius = '6px';
    badge.style.fontSize = '11px';
    badge.style.fontWeight = '600';
    badge.style.cursor = 'pointer';
    badge.style.userSelect = 'none';
    badge.style.transition = 'all 0.2s ease';

    if (dark) {
      badge.style.color = '#38bdf8';
      badge.style.background = 'rgba(56, 189, 248, 0.12)';
      badge.style.border = '1px solid rgba(56, 189, 248, 0.28)';
    } else {
      badge.style.color = '#0284c7';
      badge.style.background = 'rgba(2, 132, 199, 0.1)';
      badge.style.border = '1px solid rgba(2, 132, 199, 0.25)';
    }
  }

  function renderBadge() {
    const trigger = document.querySelector('[data-testid="model-selector-trigger"]');
    if (!trigger) return;

    let badge = document.getElementById('antigravity-usage-badge');
    if (!badge) {
      badge = document.createElement('span');
      badge.id = 'antigravity-usage-badge';

      const svg = trigger.querySelector('svg');
      if (svg) {
        trigger.insertBefore(badge, svg);
      } else {
        trigger.appendChild(badge);
      }
    }

    applyThemeStyles(badge);

    const dark = isDarkTheme();
    const dotColor = dark ? '#38bdf8' : '#0284c7';
    const dotShadow = dark ? '0 0 5px #38bdf8' : 'none';

    const sessPct = currentUsage.session ? Math.round(currentUsage.session.used_pct) : 0;
    const sessReset = currentUsage.session ? currentUsage.session.resets_in : 'N/A';
    const weekPct = currentUsage.weekly ? Math.round(currentUsage.weekly.used_pct) : Math.round(sessPct * 0.7);

    badge.title = 'Session: ' + sessPct + '% (Resets in: ' + sessReset + ') • Weekly: ' + weekPct + '% used';
    badge.innerHTML = '<span style="width:5px;height:5px;border-radius:50%;background:' + dotColor + ';display:inline-block;box-shadow:' + dotShadow + ';"></span><span>' + sessPct + '%</span><span style="opacity:0.35;font-size:10px;margin:0 1px;">|</span><span style="opacity:0.85;font-size:10.5px;">W: ' + weekPct + '%</span>';
  }

  // Watch for theme changes
  const themeObserver = new MutationObserver(() => {
    const badge = document.getElementById('antigravity-usage-badge');
    if (badge) applyThemeStyles(badge);
  });
  themeObserver.observe(document.body, { attributes: true, attributeFilter: ['class', 'style'] });
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class', 'style'] });

  // Periodic quota check
  setInterval(() => {
    fetchStoredQuota().then(renderBadge);
  }, 15000);

  fetchStoredQuota().then(renderBadge);

  const domObserver = new MutationObserver(() => {
    const trigger = document.querySelector('[data-testid="model-selector-trigger"]');
    const badge = document.getElementById('antigravity-usage-badge');
    if (trigger && !badge) {
      renderBadge();
    }
  });
  domObserver.observe(document.body, { childList: true, subtree: true });
})();

(function marketplaceTopbarButton() {
  const CLASS = "jc-marketplace-pill";
  const STYLE_ID = "jc-marketplace-style";
  const ROUTE = "/marketplace";

  function wait() {
    if (
      !window.Spicetify?.Topbar?.Button ||
      !window.Spicetify?.Platform?.History
    ) {
      setTimeout(wait, 300);
      return;
    }
    init();
  }

  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;

    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      .${CLASS} {
        margin-left: 12px; /* ← LEFT SPACE */
        display: flex !important;
        align-items: center !important;
      }

      .${CLASS} button,
      .${CLASS} [role="button"] {
        height: 40px !important;
        min-width: 110px !important;
        padding: 0 14px !important;
        border-radius: 999px !important;

        display: inline-flex !important;
        align-items: center !important;
        justify-content: center !important;
        gap: 8px !important;

        background: rgba(255,255,255,0.08) !important;
        border: none !important;
        font-size: 14px !important;
        font-weight: 600 !important;
        color: white !important;

        transition: background 0.15s ease;
      }

      .${CLASS} button:hover {
        background: rgba(255,255,255,0.16) !important;
      }

      .${CLASS} svg {
        width: 20px !important;
        height: 20px !important;
        flex: 0 0 auto;
      }

      .${CLASS} span {
        line-height: 1;
      }
    `;
    document.head.appendChild(style);
  }

  function icon() {
    return `
      <svg viewBox="0 0 24 24" fill="none">
        <path 
          d="M4 7h16M6 7v12h12V7M8 4h8l1 3H7l1-3Z" 
          stroke="currentColor" 
          stroke-width="1.8"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    `;
  }

  function create() {
    if (document.querySelector(`.${CLASS}`)) return;

    const button = new Spicetify.Topbar.Button(
      "Marketplace",
      icon() + `<span>Marketplace</span>`,
      () => Spicetify.Platform.History.push(ROUTE),
    );

    if (!button?.element) return;

    button.element.classList.add(CLASS);

    window.__marketplaceButton = button;
  }

  function init() {
    injectStyle();
    create();
  }

  wait();
})();

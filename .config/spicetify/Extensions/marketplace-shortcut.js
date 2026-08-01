(function initializeMarketplaceShortcut() {
  if (
    typeof Spicetify === "undefined" ||
    !Spicetify.Topbar?.Button ||
    !Spicetify.Platform?.History
  ) {
    setTimeout(initializeMarketplaceShortcut, 100);
    return;
  }

  const marketplaceIcon = `
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path fill="currentColor" d="M7 4h-2l-1 2h2l2.4 7.2a2 2 0 0 0 1.9 1.4h6.9a2 2 0 0 0 1.9-1.4l1.5-5.2h-12.9l-.7-2zm3.5 12.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3zm6 0a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z"/>
    </svg>
  `;

  new Spicetify.Topbar.Button(
    "Marketplace",
    marketplaceIcon,
    () => Spicetify.Platform.History.push("/marketplace"),
    false,
    true,
  );
})();

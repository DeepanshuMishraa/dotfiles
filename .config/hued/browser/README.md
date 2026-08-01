# Hued for Web

The extension receives the active semantic palette from the local `hued` binary through Chrome native messaging. It never edits Arc's profile database. A computed-style engine covers neutral surfaces on arbitrary sites, while maintained adapters provide precise token mappings for GitHub, Notion, LinkedIn, X/Twitter, and YouTube. Images, video, canvas content, and saturated brand colors are preserved.

## Arc development setup

1. Build and install the `hued` binary.
2. Open `arc://extensions`, enable Developer mode, and load this `browser` directory unpacked.
3. Copy the assigned extension ID.
4. Run `hued browser setup --browser arc --extension-id <id>`.
5. The extension retries the native connection automatically, including after its service worker sleeps. Reload the extension once when upgrading its source.
6. Run `hued set <theme>`; already-open ordinary tabs update through the long-lived native connection without restarting Arc.

Arc-owned pages, extension stores, and other Chromium-protected pages cannot be styled.

On macOS, Arc currently discovers native hosts through the Google Chrome-branded user registry. Hued handles that path internally; `--browser arc` is still the correct command.

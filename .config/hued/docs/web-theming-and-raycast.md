# Web theming and Raycast integration notes

## Browser strategy

No finite generic stylesheet can correctly theme arbitrary websites: applications define colors at root variables, component rules, inline styles, SVGs, shadow roots, and runtime-generated DOM. Dark Reader's maintained implementation analyzes pages dynamically and still ships site-specific fixes, which validates a hybrid design rather than a single blanket rule ([Dark Reader source and architecture](https://github.com/darkreader/darkreader)).

Hued therefore uses three layers:

1. Semantic CSS variables carrying the selected Hued palette.
2. Exact adapters for stable application tokens and semantic selectors on high-value sites.
3. A conservative computed-style classifier for unknown neutral surfaces, text, and borders. It assigns semantic attributes rather than inline colors, preserving instant theme switching and per-domain disablement. Media and saturated brand colors are excluded.

Chromium content scripts cannot style browser-owned pages or browser chrome. Native messaging is only the palette transport; the browser starts a registered executable and communicates over framed stdin/stdout ([Chrome native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)).

## Raycast

Raycast supports custom background, primary, and support colors through Theme Studio, but this is a Raycast Pro feature ([Raycast Themes manual](https://manual.raycast.com/themes)). Themes can be switched from Raycast's interactive **Switch Theme** command and shared/imported through Raycast-managed URLs.

Raycast's documented external automation surface is command deeplinks. Deeplinks ask for confirmation, and arguments only apply when the target command declares them; the Theme Studio documentation exposes no background “apply this JSON/theme name” API ([Raycast deeplinks](https://developers.raycast.com/information/lifecycle/deeplinks)). The extension API exposes the current light/dark appearance to extensions, not a setter for the host application's palette ([Raycast environment API](https://developers.raycast.com/api-reference/environment)).

Consequently, Hued must not edit Raycast's private encrypted databases or pretend arbitrary palette switching is supported. Safe integration today is limited to Raycast following the macOS light/dark appearance. Exact palette automation needs a future public import/apply API, or a one-time supported theme import plus a supported named-theme command argument.

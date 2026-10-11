# Google sign-in assets

This folder owns only the local assets used by `GoogleSignInButton`.
Nothing is fetched at runtime. The app's ordinary typography is unchanged.

- `g-logo.png`: unmodified official multicolor gradient G from
  <https://developers.google.com/static/identity/images/g-logo.png>.
  SHA-256: `d1ce9c2af0b10a7333abc99bc706f9a6a199e5b65bf3e3009624f076b8638e6a`.
- `GoogleSans-Medium.ttf`: Google Sans Medium delivered by the official
  [Google Fonts CSS API](https://fonts.googleapis.com/css2?family=Google+Sans:wght@500&display=swap),
  downloaded unchanged from
  <https://fonts.gstatic.com/s/googlesans/v71/4Ua_rENHsxJlGDuGo1OIlJfC6l_24rlCK1Yo_Iqcsih3SAyH6cAwhX9RFD48TE63OOYKtrw2IKli.ttf>.
  SHA-256: `81af36b42b8c5f66fb29fe04995d43ba3c6589b62ad34e9fe428fb2c162715a5`.
- `OFL.txt`: Google Sans SIL Open Font License, bundled with the app alongside
  the font, from <https://github.com/google/fonts/blob/main/ofl/googlesans/OFL.txt>.

Retrieved 2026-10-11. The
[official branding guidelines](https://developers.google.com/identity/branding-guidelines)
specify Google Sans Medium, a standard-color G, theme colors and spacing.
The live EN/IT label can wrap at large accessibility text sizes; the 18px square
G retains its aspect ratio and white background and is excluded from semantics
so the button is announced once. No tint, hand-drawn replacement, unrelated font
or sign-in UI package is included.

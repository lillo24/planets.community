# 04A navigation follow-up: manual merge gate

PR #10 remains unmerged and roadmap 04A remains **In progress**. These checks
require a person running the native Android/iOS application. They have **not**
been marked passed by automated widget tests or command-line validation.

1. Launch: one navigation bar is visible, ordered Profile / Browse / Home, with Home selected.
2. Select each destination and verify the selection and screen agree, including direct profile/detail links.
3. Use Home's Browse proposals CTA and confirm Browse selection.
4. Open a proposal from Browse and use AppBar Back and Android system Back to return to the list.
5. Set filters and scroll Browse, switch Home then Browse, and confirm restoration; repeat while on a detail.
6. While signed out, select Profile, complete email OTP Auth (no bottom bar), and verify the return destination.
7. With an incomplete profile, open completion and escape through Home/Browse; Create/My proposals must still require completion.
8. Verify Save profile is immediately visible on both setup and edit, including on a small screen with the keyboard open.
9. Save display name, bio, skills and visibility; verify Profile reflects them. Check invalid input, progress/duplicate-submit prevention and visible safe errors.
10. From a complete Profile, enter Edit and use Back to return to Profile.
11. Open the Skills dropdown: the keyboard must stay closed (also after editing locality).
12. Explicitly tap skill search: the keyboard should open; verify results, category search and scrolling on a small screen.
13. Select several skills; Apply should close the menu and show at most two badges plus the remaining count. Reopen to verify selections.
14. Clear all and Apply; confirm the filter is removed. Dismiss an unapplied change and verify it was not committed.
15. Combine locality and several skills; confirm matching-any-skill results, pagination, empty state and retry behavior.
16. Create/edit a proposal, switch tabs and return; verify unsaved values and navigation are preserved. Re-tap the active tab and confirm no reset.
17. Sign out/switch accounts with profile/proposal forms open or hidden, including during save; no prior private values may remain and stale work must not affect the new account.
18. Hot reload on each branch (including nested screens) and verify the shell, selection and navigation stay coherent.

Do not merge until the final reviewer has completed the applicable native checks.

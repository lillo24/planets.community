# UIAUDIT01 — Pixel 9 Pro native review

**Status: partial audit; 418 original captures individually opened and reviewed.** The inventory has 274 entries: 235 captured, 33 blocked and 6 not applicable. Every remaining gap is listed in the adjacent [sanitized record](uiaudit01-pixel9pro-review.json). A captured callsite proves the stated native state, not every possible branch.

Audited product source: `b9a8603fb9b28e07d07c36bf855d60959454de19`, app `0.1.10+14`, Flutter 3.47.2 / Dart 3.13.2, profile integration target. The final driver is committed with [local tooling and reproduction instructions](../../scripts/ui-audit/README.md). Three APK/driver boundaries are recorded in the private source archive. The first two exact historical driver patches were not retained; product library files were unchanged. Intermediate main `52e301bb` matched the captured product. Integration main `34649049` adds PR #309 Community calendar UI and a migration after captures were frozen. Its two new routes and changed hub/meeting entry controls are explicitly unreviewed (L001/L002 in the coverage supplement).

Device: SDK `pixel_9_pro` AVD, Android 16 / API 36, Google APIs x86_64 revision 7. Original PNGs are 1280 × 2856; density 480 / DPR 3 gives 426.7 × 952 dp, gesture navigation and 156/72 px closed-keyboard insets. Main pass: Italian/dark/default scale; focused English/light and Android font scale 1.8, restored to 1.0. System photo picker and Gboard are genuine native handoffs.

The delivered `PLANETS_UIAUDIT01_Review.pdf` and `PLANETS_UIAUDIT01_Sources.zip` contain the full evidence, original hashes, phone-readable decision cards, notes, complete route/state inventory and persona matrix. They remain outside Git. No credentials, OTPs, bearer invitation links, raw widget diagnostics or real-account messages are committed.

## Accounts and evidence

| Real selector persona | Individually reviewed captures |
| --------------------- | ------------------------------ |
| Giulia                | 169                            |
| Marco                 | 46                             |
| Sara                  | 13                             |
| Dario                 | 23                             |
| Elena                 | 17                             |
| Luca                  | 35                             |
| Maya                  | 14                             |
| Nora                  | 6                              |
| Teo                   | 5                              |
| Iris                  | 52                             |

All ten are the original canonical Mock personas using an actual local broker/Auth flow. Guest and genuine local email/OTP/policy/profile journeys supplement them. Google OAuth was unconfigured: KP/KQ are equivalent OTP-only entries, and a Google provider handoff was not captured. Two independently keyed, task-owned disposable Supabase realms used canonical migrations. Initial canonical seed qualification passed 93 checks. Native fictional interactions and additive ordinary RPC fixtures exercise both sides of relationships.

## Repeated-person inbox

The supplied `Screenshot_20261023-102754.png` was unavailable after attachment/filesystem discovery; A remains reserved. Local typed results show separate Resource and participation domains for the same pair. Reversed Project/Tavolo participation retains one canonical pair conversation; 24 distinct native composite keys were rendered through automatic pagination. No duplicate `(kind, chatId)` or participation anchor was proven, so no duplicate-chat fix was made. A1 proposes visible context without hiding rows, merging histories, or deciding universal one-person messaging. Installed-app parity and the real-account cause remain unconfirmed.

## Pending decisions

Every proposal remains pending after this audit tooling merges. One underlying change has one permanent ID and one vote. DU1, GL1, FO1 and OA1 are review priorities; A1 addresses the reported ambiguity.

### A1 — Give repeated-person chat rows visible context

copy/usability; impact medium; confidence: high for the local reproduction; unconfirmed for the supplied installed build. **Decision: pending.**

R shows two Marco rows with different previews and no conversation label. The supplied real-account image is missing, so its hidden cause remains unconfirmed.

Supporting diagnosis: Task-local typed results identify separate Resource and participation chat kinds. Reversed Project/Tavolo requests retain one pair conversation; 24 native composite keys remain distinct through pagination. These checks do not establish the hidden cause in the missing installed-app reference.

Proposal: Add a compact context line to private inbox rows, identifying the conversation type and the relevant listing, project or group without merging histories.

Evidence IDs: R, U, BE, IL, IM.

### P1 — Use the discovery name in Settings

copy/usability; impact low; confidence: high. **Decision: pending.**

The setting says “Modalità Co-creazione”, while the feature and help describe “Trova persone”.

Proposal: Rename this setting to “Trova persone (sperimentale)”.

Evidence IDs: P.

### AA1 — Replace lifecycle jargon in the management menu

copy/usability; impact low; confidence: high. **Decision: pending.**

The menu labels an ordinary organizer action “Dettagli del progetto e ciclo di vita”.

Proposal: Rename this menu item to “Dettagli e stato del progetto”.

Evidence IDs: AA, IH.

### AU1 — Shorten the Resource search hint

copy/usability; impact low; confidence: high. **Decision: pending.**

The default Italian search placeholder is truncated to “Cerca nel titolo e nella descrizio…”.

Proposal: Use “Cerca un annuncio” as the placeholder, retaining the existing title-and-description search behavior.

Evidence IDs: AU, BJ.

### BL1 — Keep the full privacy audience statement visible

confirmed layout defect; impact medium; confidence: high. **Decision: pending.**

The private-note helper ends with an ellipsis at default text size, hiding the end of the audience explanation.

Proposal: Allow the note privacy helper to wrap to show the complete sentence.

Evidence IDs: BL.

### BL2 — Call the listing an annuncio

copy/usability; impact low; confidence: high. **Decision: pending.**

The agreement sheet says “Il proprietario della lista fornisce”, using lista for the listing.

Proposal: Replace this label with “Il proprietario dell’annuncio offre”.

Evidence IDs: BL, JI, NY.

### CQ1 — Format People chat timestamps for reading

copy/usability; impact low; confidence: high. **Decision: pending.**

General and numbered chat messages show full numeric dates with six fractional-second digits. This makes routine message metadata unnecessarily long.

Proposal: Use the existing localized compact message date/time format for People chat metadata, omitting seconds and microseconds.

Evidence IDs: CQ, CS, DI, DT, DX, EA, ED, EG, EH, LL.

### DE1 — Give post authors a management action

copy/usability; impact medium; confidence: high. **Decision: pending.**

Maya sees Mi interessa and a private request field on her own published post. My posts separately identifies her as its owner.

Proposal: When the active user owns a People post, replace its interest form with a Gestisci il tuo annuncio link to the existing own-post controls.

Evidence IDs: DE, DF, DD.

### DK1 — Explain People close and withdraw confirmations

copy/usability; impact medium; confidence: high. **Decision: pending.**

The close page repeats Chiudi for its title, toolbar exit and main button. The withdrawal page similarly shows only Ritira. Neither identifies the affected conversation/post or explains the consequence.

Proposal: Add clear action/consequence confirmations for closing a People contact or withdrawing interest. Use currently authorized post/contact context when available, preserve identity-only recovery privacy, and distinguish the action from Annulla.

Evidence IDs: DK, DR, IU, KH.

### DU1 — Show inbox empty states only when all sections are empty

confirmed defect; impact medium; confidence: high. **Decision: pending.**

Teo has a pending People request above Nessun messaggio. Iris has an accepted contact and unread badge above Ancora nessuna chat privata. Both screens contradict their visible content.

Proposal: Compute the inbox empty state across native, People and discussion sections, showing it only after all applicable sections have loaded and are empty.

Evidence IDs: DU, DZ, FQ.

### DY1 — Name the numbered-group exit correctly

copy/usability; impact medium; confidence: high. **Decision: pending.**

A numbered group chat and its exit page say Lascia la comunità, although the warning describes leaving this group and retaining other groups. This can look like a broader community exit.

Proposal: Use Lascia il gruppo on numbered-group chat and exit controls, reserving Lascia la comunità for the hub exit. Keep the existing access and archive rules.

Evidence IDs: DY, DX, EG, EH, KE, LL.

### FW1 — Show template duration in hours and minutes

copy/usability; impact low; confidence: high. **Decision: pending.**

The template detail displays Durata indicativa: 10800.0 secondi. This requires mental conversion and exposes unnecessary numeric precision.

Proposal: Format template durations in localized hours and minutes, for example Durata indicativa: 3 ore, while keeping the stored duration unchanged.

Evidence IDs: FW, FX.

### GI1 — Translate the safety request target label

copy/localization; impact low; confidence: high. **Decision: pending.**

An Italian review-request card contains the English target label Resource request.

Proposal: Localize the resource-request target label as Richiesta Scambio-Dona in the safety request list.

Evidence IDs: GI.

### GL1 — Show every witness response in full

confirmed layout defect; impact medium; confidence: high. **Decision: pending.**

All three witness-response buttons cut off their Italian sentences. A safety response should be readable before selection.

Proposal: Allow the three witness-response labels to wrap and grow vertically so each complete existing sentence is visible at default and increased text sizes.

Evidence IDs: GL, GM, JP, JQ, JR.

### FO1 — Keep submitted People reports readable in My reports

confirmed contract defect; impact medium; confidence: high. **Decision: pending.**

The report receipt succeeds, then My reports displays a read failure.

Supporting diagnosis: A separate ordinary Iris v4 RPC read returns a cocreate_post row with target_summary=null. The current mobile parser requires bounded nonempty text. This supports a projection/parser contract defect; it is not visible in the screenshot itself.

Proposal: Complete the own-report projection for People targets so it returns a privacy-safe localized summary accepted by the existing parser, with regression coverage for a newly submitted People report.

Evidence IDs: FO, FN, KI.

### HS1 — Name General history correctly

copy; impact low; confidence: high. **Decision: pending.**

The Generale chat footer says Cronologia completa dell’Idea, although this is the Group General conversation.

Proposal: Use the General-specific history label in General conversations while retaining the existing access warning.

Evidence IDs: HS.

### IR1 — Remove the raw creator UUID from Idea discovery

copy/usability; impact low; confidence: high. **Decision: pending.**

Before joining an Idea, Dario sees Creatore dell’Idea followed by a 36-character profile UUID.

Supporting diagnosis: Current source intentionally avoids an additional profile lookup. The proposed copy keeps that privacy boundary.

Proposal: Replace the UUID line with Creatore: disponibile nella vista Persone autorizzata when no authorized display name is already available. Keep the current read permissions and avoid adding profile or roster lookups.

Evidence IDs: IR, MD.

### KT1 — Describe invalid codes accurately

copy/usability; impact low; confidence: high for observed behavior; backend error classification is ambiguous. **Decision: pending.**

Fresh 000000 is described only as expired. The actual delivered code still worked immediately afterward, so requesting another code was unnecessary.

Proposal: For the ambiguous backend OTP error, use “Il codice non è valido o è scaduto. Controllalo o richiedine uno nuovo.”

Evidence IDs: KT.

### KX1 — Show the complete profile-name validation

confirmed layout defect; impact low; confidence: high. **Decision: pending.**

The display-name validation message ends in an ellipsis before explaining the complete whitespace restriction.

Proposal: Allow the existing display-name validation error to wrap onto enough lines to show its complete text.

Evidence IDs: KX, KY, KZ.

### MT1 — Localize the generic blocking target

copy/localization; impact low; confidence: high; hardcoded fallback verified in BlockingActionButton. **Decision: pending.**

The Italian blocking confirmation is titled “Bloccare this user?”.

Proposal: Replace the hardcoded English fallback “this user” with the localized Italian generic “questo utente”, retaining the existing privacy boundary.

Evidence IDs: MT.

### OA1 — Label public Group saves accurately

copy/usability; impact medium; confidence: high; published editor and shared departure label verified. **Decision: pending.**

The departure dialog for a published Group offers “Salva bozza”, while the editor explains that saving updates the public page immediately. This can mislead an organizer about visibility.

Proposal: For published Groups, label this departure action “Salva modifiche pubbliche”; retain “Salva bozza” only for private drafts.

Evidence IDs: OA.

## Coverage and validation boundaries

The source ZIP lists every route, modal, pushed page and required state, including exact blockers. Main gaps include unconfigured live-event/map/place providers; selected pending/closed/loan and coordination-consent branches; policy/profile wrapper preconditions; external share/email/license completion; and privacy-sensitive bearer-link handoffs. The own-report populated success state is blocked by FO1. These are not counted as healthy successful states.

All primary route-to-image mappings were reconciled against visible UI, real navigation and current source. Pushed pages can retain a parent URI; the archive preserves both sanitized reported and effective routes. Loading, obscured, failed and repeated captures are explicitly labeled. MA recovered in MK; local memory pressure/timeouts do not establish shipped performance defects.

Local validation includes the native profile session, individual original inspection, hash/inventory checks, Dart analysis/formatting, Node syntax and meaningful disposable-guard rejection plus ordinary diagnostic reads. The fixtures were executed while developing this run; after extracting shared ownership guards, the complete fresh-world sequence was not rerun. The full `npm run check:mobile` passed on the capture baseline: 4,241 tests passed, 2 skipped, clean analysis and formatting. Node tooling tests passed 181/181 with the bundled Python directory on this process’s PATH. No claim is made that the one-time additive fixture mutations are part of recurring CI. Latest-main integration uses repository CI as the merge gate.

No general UI or canonical schema change was implemented. The narrow duplicate-fix exception was not used. Reply format: **A1 yes, A2 no, B1 yes.** This is syntax only; actual proposal IDs are those listed above. Missing answers remain pending.

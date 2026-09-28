# Pocket Pokédex

An iOS Pokédex built with SwiftUI: a paginated gallery of every Pokémon, a detail screen with base stats, level-up moves and Pokédex lore, and a persisted "team" the user marks with the `+` on any card.

Data comes from [PokéAPI](https://pokeapi.co) — a free, keyless, read-only HTTP API. There is no backend of our own, no authentication, and no third-party dependency.

---

## Running it

Requires **Xcode 26.6 or later** and the **iOS 26.5 SDK**. There is nothing to install: no SPM packages, no CocoaPods, no build scripts.

```bash
open PocketPokedex.xcodeproj      # then press ⌘R
```

From the command line:

```bash
xcodebuild -project PocketPokedex.xcodeproj -scheme PocketPokedex \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

The app needs a network connection on first launch. If you want to work offline, run a preview instead — the `Offline` preview is backed by a stubbed service (see [Previews and stubs](#previews-and-stubs)).

### Build settings worth knowing

| Setting | Value | Why it matters |
| --- | --- | --- |
| `IPHONEOS_DEPLOYMENT_TARGET` | 26.5 | The code uses iOS 17/18 APIs freely — `@Observable`, `@Entry`, `.onGeometryChange`, `FormatStyle`, `ImageResource`, `URL.cachesDirectory`. |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | **Every type is main-actor isolated unless it says `nonisolated`.** This is the single most surprising setting in the project; see [Concurrency](#concurrency). |
| `SWIFT_VERSION` | 5.0 | Swift 5 language mode. The compiler reports Swift 6 isolation violations as warnings, not errors. |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Relaxes some `Sendable` checking. |
| `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` | `YES` | Colours and motifs are referenced by generated symbol (`Color(.canvas)`, `ImageResource.motifPokeball`), never by string. |
| `TARGETED_DEVICE_FAMILY` | `1,2` | iPhone and iPad. The layout widens to a 1368pt column and the card grid gains columns. |

`Info.plist` sets `UIDesignRequiresCompatibility = true`, which keeps the pre-Liquid-Glass look on iOS 26 so the screens match the Figma mock. That is a deliberate trade-off, not an oversight — revisit it when the mock is refreshed.

There is **no test target**. Every change currently needs manual verification in a simulator.

---

## Architecture

MVVM with a service layer and an explicit composition root. The shape is deliberately boring: one direction of dependency, one place where concrete types are chosen, and no framework.

```
                    PocketPokedexApp
                              │ builds the graph once
                              ▼
                    ┌─────────────────┐
                    │ AppDependencies │   ← the composition root: the only place
                    │      .live      │     concrete services are chosen
                    └────────┬────────┘
                              │ injected into
                              ▼
    ┌────────────────────────────────────────────────────┐
    │Views (SwiftUI)                                     │
    │  HomeView → PokemonFeedView → PokemonGrid          │
    │           └→ PokemonDetailView (full-screen modal) │
    └─────────────────────────┬──────────────────────────┘
                              │ read state, call intents
                              ▼
    ┌────────────────────────────────────────────────────┐
    │ViewModels  (@Observable, @MainActor)               │
    │  PokedexFeedViewModel                              │
    │  PokemonDetailViewModel                            │
    │  TeamStore                                         │
    └─────────────────────────┬──────────────────────────┘
                              │ domain models only
                              ▼
    ┌────────────────────────────────────────────────────┐
    │Services  (protocol PokemonService)                 │
    │  LivePokemonService ─► PokeAPIClient ─► HTTPClient │
    │  CachedPokemonService   (memoising decorator)      │
    │  PreviewPokemonService  (#if DEBUG)                │
    └─────────────────────────┬──────────────────────────┘
                              │ JSON over HTTPS
                              ▼
                           PokeAPI
```

The rules that keep it that way:

- **Views never touch the network, and view models never touch `URLSession`.** Only `PokeAPIClient` builds requests; only `LivePokemonService` knows both the wire format and the domain.
- **Dependency arrows only point down.** `Networking` and `Services` know nothing about `Views`; `Models` know nothing about either.
- **The composition root chooses the concrete graph.** Views receive `AppDependencies` and ask it for view models — a view never constructs a service, and there is no singleton reachable from the UI except the image cache, which is injectable through the environment.

---

## Layers

### `Models/` — the domain

Plain value types (`struct`, `Sendable`, no SwiftUI beyond a colour lookup on `PokemonType`). These are what the rest of the app passes around; nothing here mirrors the wire format.

| Type | What it is |
| --- | --- |
| `Pokemon` | A fully loaded Pokémon: types, artwork, measurements, abilities, stats, moves. |
| `PokemonFeedItem` | A *card*. Starts as just an id and a slug from the list endpoint, then gets types and artwork filled in. |
| `PokemonPage` | One page of the feed: items, the `next` link, the total count. |
| `PokemonSpecies` | The lore half — genus, flavour text, catch rate, growth rate, the evolution chain's id. |
| `EvolutionStage` | One node of a flattened evolution chain. |
| `PokemonStat` / `StatKind` | A base stat and its six kinds, whose raw values are the API's own slugs. |
| `PokemonAbility`, `PokemonMove` | The two list-shaped details on a Pokémon. |
| `PokemonType` | The eighteen elemental types, plus their chip colours. |
| `PokemonGame`, `PokedexBackgroundTheme`, `PokedexMotif` | The theming system — see [Theming and appearance](#theming-and-appearance). |

`PokemonSpecies` deliberately carries only what a screen shows. The species endpoint returns more (its own name, colour, habitat, legendary flags); fields are added when something reads them, not for completeness.

### `Networking/` — the wire

Knows about HTTP and JSON, and nothing about Pokémon beyond what the endpoints are called.

- **`HTTPClient`** — the one seam over `URLSession`. A protocol with one method, so the whole stack can be driven by a stub.
- **`PokeAPIEndpoint`** — every route as an enum case that knows how to build its own `URLRequest` (base URL, `Accept`, timeout, `.returnCacheDataElseLoad`). Also defines `PokemonIdentifier`, the id-or-name union the API accepts in a path segment.
- **`PokeAPIClient`** — performs an endpoint and decodes it into a payload, with `convertFromSnakeCase`. Maps HTTP failures onto `PokeAPIError`.
- **`Payloads/`** — `Decodable` mirrors of the JSON, grouped by endpoint because they only ever appear inside one another. These never leave the service layer.
- **`PokeAPIError`** — every failure the stack can surface: `invalidRequest`, `invalidResponse`, `httpStatus`, `decodingFailed`, `notFound`, `transport`, `cancelled`. `PokeAPIError.from(_:)` folds `URLError` and `DecodingError` into it, and `userFacingMessage` is what the UI shows.

### `Services/` — the domain-facing seam

```swift
nonisolated protocol PokemonService: Sendable {
    func pokemonPage(limit: Int, offset: Int) async throws -> PokemonPage
    func pokemonPage(following url: URL) async throws -> PokemonPage
    func pokemon(_ identifier: PokemonIdentifier) async throws -> Pokemon
    func species(_ identifier: PokemonIdentifier) async throws -> PokemonSpecies
    func availableTypes() async throws -> [PokemonType]
    func evolutionChain(id: Int) async throws -> [EvolutionStage]
}
```

Three implementations, composed rather than switched on:

| Type | Role |
| --- | --- |
| `LivePokemonService` | The real thing: chooses endpoints, decodes payloads, maps them onto models. The **only** type that knows both the wire format and the domain. |
| `CachedPokemonService` | A decorator that memoises `pokemon`, `species`, `evolutionChain` and `availableTypes` through `ResourceMemo`. Pages are never cached — they are cheap and always advancing. |
| `PreviewPokemonService` | `#if DEBUG` only. Twenty hard-coded Pokémon, no network. Powers every preview. |

`ResourceMemo` is a small actor that both memoises and **coalesces concurrent requests**: two callers asking for the same Pokémon at the same time share one download. That is what stops the feed's card hydration and the detail modal from racing for the same resource.

`Services/Images/` holds the image pipeline — three tiers, described under [Networking and caching](#networking-and-caching).

### `ViewModels/` — screen state

Three `@MainActor @Observable` classes. They own loading, filtering and selection; they hold no SwiftUI types.

**`PokedexFeedViewModel`** drives the gallery and owns four concerns:

1. **Pagination** — which page is loading, the `next` URL, an explicit offset, and whether more pages exist.
2. **Filtering** — by type (client-side, over loaded pages) and by team membership.
3. **Card hydration** — filling in types and artwork for a freshly loaded page, a few at a time, deliberately *not* awaited so pagination is never held up by artwork.
4. **Team hydration** — fetching marked Pokémon by id, since a marked Pokémon is usually nowhere near the pages the feed has scrolled to.

Its observable state is read-only from outside (`private(set)`) apart from the two filter flags. `Phase` models the feed as `idle`, `loadingFirstPage`, `loaded` or `failed(message:)`; `nextPageErrorMessage` is separate so a failure on page 7 can be shown inline without throwing away pages 1–6.

**`PokemonDetailViewModel`** loads `/pokemon/{id}` and `/pokemon-species/{id}` concurrently, then follows the species' evolution-chain link afterwards (it only decorates one tab, so it must not delay the modal becoming usable). It also keeps the feed item it was opened with, so the header, name, artwork and types are readable on the very first frame — before any request returns.

**`TeamStore`** is the persisted mark set: a `Set<Int>` of dex numbers under the `UserDefaults` key `pokedex.team.memberIDs`. One instance is shared by the cards' `+` buttons and the floating filter, so the grid and the badge can never disagree.

### `Views/` — SwiftUI

Split into the screens, the shared components, and the detail feature.

```
Views/
  HomeView.swift            the screen: header (TopBar + TypeFilter), background, appearance
  PokemonFeedView.swift     the gallery's states, the floating button, the modal presentation
  PokemonGrid.swift         the scrolling grid, its pagination sentinel and its empty states
  Components/               shared, feature-agnostic views (18 files)
  Detail/                   the detail screen and its three tabs (7 files)
```

Every type lives in its own file. The `Views/Components/` set is the app's component library: `PokemonCard`, `TypeChip`/`TypeBadge`, `PokedexTabBar`, `PokedexButton`, `EmptyStateView`, `CachedArtworkImage`, `StatBar`, `TopBar`, `TeamFilterButton`, `PokedexSurface`, `PokedexWatermark` and a few smaller pieces.

### `DesignSystem/` — tokens

`PokedexTheme` is the single source of truth: every colour is an asset-catalog entry (so nothing builds a colour from components and every set carries its own dark appearance), and `PokedexTheme.Metrics` holds the layout numbers from the mock. `PokedexFont` holds the type scale. `PokedexViewModifiers` holds the three shared decorations — card shadow, surface fill, hairline border — that would otherwise be copy-pasted onto every panel.

### `Utilities/` — the small things

`withBoundedTaskGroup` (bounded, order-preserving, cancellation-aware fan-out), `MeasurementFormat` (height and weight strings), `PokedexNumber` (the `#001` format), `SlugDisplayName` (turns `special-attack` into `Special Attack`).

---

## How the screens work

### Launch and the first page

`PocketPokedexApp` builds `AppDependencies.live` once and hands it to `HomeView`, which asks it for a `PokedexFeedViewModel`. `HomeView`'s `.task` calls `start()`, which fires two independent requests concurrently: `/type` for the filter chips and `/pokemon?limit=40&offset=0` for the first page.

The moment the page lands, the cards render immediately with their names and dex numbers — those came from the list endpoint — while `hydrateDetails` fetches `/pokemon/{id}` for all forty cards, six at a time, and fills in types and artwork as each arrives. Cards paint one by one rather than all at once.

### Pagination

Scrolling is what drives it. The last cell inside the `LazyVGrid` is a zero-height sentinel carrying a `.task(id:)` that re-arms on `loadedPageCount`; when the grid reaches it, it asks the view model for the next page.

**The sentinel must stay inside the lazy container.** A sentinel placed *after* the grid in the `ScrollView` is built the moment the screen appears, and its task then pulls page after page with nobody scrolling — which is exactly what the app used to do, fetching all 1,351 Pokémon in 34 requests at launch. This is documented in [CODE_AUDIT.md](CODE_AUDIT.md) §5.1 and is the single easiest way to reintroduce a serious bug here.

Because the sentinel only exists while it is in view, the same mechanism makes type filtering work: a filter that matches nothing yet leaves the sentinel visible, so the feed keeps filling itself, paced by a short delay in `loadMoreIfNeeded()`.

### Opening a Pokémon

Tapping a card sets `selectedItem`, which presents the detail as a `fullScreenCover`. The feed asks `AppDependencies` for a fresh `PokemonDetailViewModel` for that item, so each presentation starts clean — and the screen gets its first frame from data the feed already had.

### Marking a Pokémon

The `+` on a card calls `TeamStore.toggle(_:)`, which updates the set and writes it to `UserDefaults`. The card's own state (`isInTeam`), the floating button's badge and the team filter's results all read the same store, so they cannot drift apart.

Tapping the floating button flips the grid's source from the paginated feed to the marked set. The view model fetches any marks it does not already hold — by id, not by filtering the loaded pages — and the grid re-renders from `teamItems`. Pull-to-refresh reloads whichever source is showing.

### Theming and appearance

The top bar carries two controls:

- **A theme menu** — `Default` plus one entry per mainline game. A theme is a wash of that version's colour *plus* a tiled watermark of a symbol associated with it. `PokemonGame` maps each title to a motif and two catalog colours (the wash and a watermark variant pre-blended toward the text colour, so a pale Yellow or a near-black Black stays visible). `PokedexMotif` draws thirteen symbols — nine as vector paths built in a unit square, four as template images — and `PokedexWatermark` tiles the chosen one in a `Canvas`, offsetting every other row so a grid reads as wallpaper.
- **An appearance toggle** — light/dark. It starts at `nil`, which means *follow the system*, and pins an explicit scheme only once the user asks for one. Nothing is persisted yet: the theme and the appearance both reset on relaunch while the team marks do not.

---

## Concurrency

The project builds with **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**, so isolation is opt-*out* here rather than opt-in. Everything is main-actor isolated by default, and the types that must be usable from a background executor say so explicitly:

- Every type in `Networking/` and `Services/` is `nonisolated` — protocol, struct, payload and error alike.
- The three `@Observable` view models are main-actor, and `@MainActor` is written out on them so the intent survives a change to the build setting.
- `ImageCache` and `ResourceMemo` are `actor`s: mutable shared state gets an actor, not a lock and not `@unchecked Sendable`.

Rules the code follows:

- **`async`/`await` only.** No GCD, no `Task.detached`, no completion handlers.
- **Fan-out is bounded and cancellable.** `withBoundedTaskGroup(over:maxConcurrent:)` keeps at most *n* operations in flight, preserves input order, and stops topping the group up when the surrounding task is cancelled.
- **Unstructured tasks are held.** Long-lived work (card hydration, the page request) is stored so a refresh can cancel it, rather than being fired and forgotten.
- **Cancellation is checked before state is written.** A cancelled image load is a recycled cell, not a failure.

---

## Networking and caching

Everything goes to `https://pokeapi.co/api/v2` over HTTPS. There is no API key, no `NSAppTransportSecurity` exception, and nothing sensitive is stored — the only persisted state is the team set.

Two caches sit in front of the network, at different levels:

**JSON** — `CachedPokemonService` memoises individual resources in memory through `ResourceMemo` (per `PokemonIdentifier` and per chain id), and `URLCache` backs it at the HTTP layer because endpoints request `.returnCacheDataElseLoad`. Pages are excluded on purpose: they advance, and pull-to-refresh must actually refetch.

**Images** — `actor ImageCache` is the app's single image pipeline, with three tiers:

1. **Memory** — `NSCache` of decoded `UIImage`s, capped at 400 items and 96 MB of *decoded* bytes. Reads are synchronous (`cachedImage(for:)` is `nonisolated`) so a card scrolled back into view can paint in the same frame instead of flashing a placeholder.
2. **Disk** — raw bytes under `Caches`, named after the SHA-256 of the URL, so names are filesystem-safe and the system may reclaim them at will.
3. **Network** — its own `URLSession` with a six-connection cap and no `URLCache`, because the actor already owns disk caching.

Concurrent requests for one URL are coalesced into a single download, and the in-flight entry is cleared on **both** success and failure — leaving a failed download behind would replay that error for the life of the process and make the URL permanently unloadable.

Views reach the cache through the `\.imageCache` environment value and never through the singleton, so a preview can substitute a stub.

---

## Previews and stubs

Every preview takes a dependency graph rather than reaching for the live one:

```swift
#Preview("Offline") {
    HomeView(dependencies: .preview)
}
```

`AppDependencies.preview` swaps in `PreviewPokemonService` (twenty Pokémon, no network) and `PreviewImageCache` (resolves nothing, so the placeholder and failure treatments are what you see), and points `TeamStore` at a scratch `UserDefaults` suite so tapping `+` in a preview cannot edit your real team.

That is the extension point for tests too: construct `AppDependencies` with a stub `PokemonService` and call the initializer directly.

---

## Conventions

**Layout.** One type per Swift file, named after the type. Folders are layers, not features. Files the compiler picks up automatically — the target uses a file-system-synchronized group, so adding, renaming or deleting a file needs no project edit.

**Naming.** Spell words out. `PokemonPayload`, not `PokemonDTO`; `dexNumber`, not `formattedID`; `hitPoints`, not `hp`; `pokemonService`, not `apiService`; `memberIdentifiers`, not `memberIDs`.

Four deliberate exceptions, all of which are somebody else's name for the thing: `URL` and `id` (Apple's own API), `HTTP` (the protocol's own name, as in `HTTPClient`), and `PokeAPI` in the three transport types that exist specifically to speak its wire format — `PokeAPIEndpoint`, `PokeAPIClient`, `PokeAPIError`. The protocol above them, which the app talks to as a domain service, is `PokemonService`.

**View models.** `@MainActor @Observable`, state `private(set)` unless the view must bind to it, intents as small methods (`loadTeam()`, `toggleTeamFilter()`, `refresh()`), and no SwiftUI import unless the type genuinely needs one.

**Views.** Extract a subview rather than growing a body or adding another computed `some View` property. Prefer a ternary over `if`/`else` when only a value changes. Put animations on the modifier that owns them, with a `value:` to watch, and gate large-motion animations on `accessibilityReduceMotion`. Give every icon-only button a label. Use design tokens instead of literal numbers.

**Comments.** Explain *why*, not *what* — the non-obvious constraint, the thing that looks wrong but is deliberate, the trap. Several bugs in this codebase came from a comment that described the intent while the code did something else, so if you change behaviour, change the comment above it.

---

## Known gaps

Carried forward deliberately; each is expanded with file and line references in [CODE_AUDIT.md](CODE_AUDIT.md).

- **Dynamic Type is not supported.** The type scale uses fixed point sizes and most text rows have fixed heights, both taken from the mock. A user who raises their text size sees no change. Fixing it means making the scale relative *and* relaxing the fixed frames, screen by screen, with the design.
- **Nothing user-facing is persisted except the team.** The background theme and the appearance override reset on relaunch.
- **Type filtering is client-side.** A type whose members all sit past the first page is found by pulling pages until one appears. `/type/{name}` returns the complete member list in one request and would bound that cost.
- **No tests.** Every change is verified by hand.
- **A few controls are under the 44pt tap target** — the filter chips and the top-bar controls — because the containers that hold them are fixed by the mock. The card's `+` has been widened to 44pt without moving the glyph.
- **Measurements follow the device locale.** `MeasurementFormat` uses `FormatStyle`, so a comma-decimal locale shows `0,7 m`. Pin the locale if the design requires a full stop unconditionally.

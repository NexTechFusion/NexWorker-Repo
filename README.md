# NexWorker Astro-Starter Kit 🚀

Dieses Repository ist dein neuer Standard für alle Nextech Landingpages.

## Warum das hier?
- **Consistency**: Alle Seiten nutzen das gleiche `Layout.astro`.
- **Speed**: 0 KB Client-side JavaScript standardmäßig.
- **Components**: Bearbeite den Header einmal, und er ändert sich auf allen 100 Seiten.
- **SEO/AEO**: Strukturiert für 2026.

## Struktur
- `src/layouts/Layout.astro`: Das Master-Template (Header, Footer, CSS).
- `src/components/`: Deine Legosteine (`Hero`, `MetricBanner`, `ProblemSolution`).
- `src/pages/`: Deine eigentlichen Landingpages als `.astro` Files.

## Starten
1. Installiere Node.js
2. `npm install`
3. `npm run dev` (lokale Vorschau unter localhost:4321)
4. `npm run build` (generiert den `dist/` Ordner mit fertigem HTML für deinen Server)

## Landingpage hinzufügen
Kopiere einfach eine vorhandene Datei in `src/pages/`, nenne sie um (z.B. `neue-seite.astro`) und passe die Texte im Frontmatter (`---`) an.

Viel Spaß beim Skalieren! 🏗️

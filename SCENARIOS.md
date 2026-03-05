# NexWorker: Einsatz-Szenarien & Simulationen

Effizienz-Fokus: Minimale Eingabe, maximale Daten-Extraktion.

## 📅 Szenario 1: Der Tagesstart (Kapazitäts-Check)
*   **07:00 Uhr:** Monteur schickt Sprachnachricht im Auto.
*   **Input:** "Moin, hier Axel. Bin heute mit Lars beim Projekt 'Neubau Allee'. Wir fangen jetzt an."
*   **NexWorker Reaktion:** Erkennt Team (Axel & Lars), Ort (Neubau Allee) und Zeitstempel.
*   **Datenpunkt:** Belegungskalender aktualisiert; ERP weiß, dass Personal vor Ort ist.

## 🛠️ Szenario 2: Material-Dokumentation (Ad-Hoc)
*   **10:30 Uhr:** Foto von 3 leeren Kabeltrommeln und angebrochenem Spachtelsack.
*   **Input:** (Nur Foto + Sprachnachricht): "Brauchen Nachschub für morgen. Haben die 3x1.5er Trommeln aufgebraucht."
*   **NexWorker Reaktion:** Analysiert Foto, erkennt Kabeltyp. Erstellt Material-Bedarfsliste im ERP.
*   **Datenpunkt:** Automatisierte Bestellung oder Lager-Pickliste für den nächsten Morgen.

## ⚠️ Szenario 3: Der Blocker (Mängel-Management)
*   **14:15 Uhr:** Arbeiter steht vor verschlossener Tür oder falscher Vorleistung.
*   **Input:** "Kann nicht weiter machen. Der Trockenbau ist noch nicht fertig. Siehe Foto. Ich fahre jetzt zum Lager."
*   **NexWorker Reaktion:** Markiert Projekt als "Blocked". Informiert Projektleiter.
*   **Datenpunkt:** Beweissicherung im Bautagebuch (Foto + Zeitstempel) zur Abwehr von Verzugsstrafen.

## 🏁 Szenario 4: Feierabend & Report (Der "Magic Moment")
*   **16:30 Uhr:** Sprachbericht zum Tagesabschluss.
*   **Input:** "Fertig für heute. 20 Steckdosen gesetzt, Flur oben ist durch. 8 Stunden gearbeitet."
*   **NexWorker Reaktion:** Rechnet Stunden ab, hakt Meilenstein "Flur oben" ab.
*   **Datenpunkt:** Lohnabrechnung vorbereitet; Leistungsstand für Abschlagsrechnung aktualisiert.

## 📈 Wochen-Zusammenfassung (Für den Chef)
*   **Freitag 16:00 Uhr:** Proaktive PDF an den Inhaber.
*   **Output:** "Zusammenfassung Woche 10: 140h geleistet, 80% Materialverbauch vs. Kalkulation, 2 Mängel dokumentiert. Alle Berichte DSGVO-konform archiviert."

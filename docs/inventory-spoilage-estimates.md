# Automatic batch spoilage estimates

SeedRover shows a rough marketability estimate beside each receipt or harvest in
web and mobile Stock Movements. Staff enter the item, quantity, and ordinary
movement details; the application assigns the supported product profile and
date basis automatically. Estimates are handling prompts, not food-safety
determinations, sales restrictions, or automatic stock disposal.

The version 1 reference catalogue contains whole-day application defaults
derived from Philippine and open-storage research. These are not validated
predictions for SeedRover farms:

| Automatic profile | Days | Evidence and limits |
| --- | ---: | --- |
| Pechay (25-day crowns) | 2 | NAST study at 27–32°C; observed ambient marketability about 2.3 days. [Study](https://doi.org/10.57043/transnastphl.1997.5952) |
| Rambutan (ripe) | 3 | Red-ripe Maharlika fruit; about 3.2 days ambient. [Study](https://doi.org/10.57043/transnastphl.1997.5952) |
| Tomato (mature-green) | 13 | Mature-green Improved Pope; other cultivars and maturity differ. Bare “Tomato” names use this visible default assumption. [Study](https://doi.org/10.57043/transnastphl.1997.5952) |
| Sweet pepper (green) | 8 | Grossum peppers; about 8.1 days. [Study](https://doi.org/10.57043/transnastphl.1997.5952) |
| Mango (mature-green) | 10 | Study fruit about 114 days after flower induction; about 10.3 days. [Study](https://doi.org/10.57043/transnastphl.1997.5952) |
| Saba banana (mature-green) | 10 | Full three-quarter fruit; about 10.3 days. [Study](https://doi.org/10.57043/transnastphl.1997.5952) |
| Pako, green alugbati, malunggay leaves | 2 | Smallholder study used banana-leaf wrapping and brick-walled evaporative cooling. [Research record](https://agris.fao.org/search/en/providers/123818/records/6748c8567625988a3720c1db) |
| Green kamote tops | 3 | Same Philippine smallholder study and storage conditions. [Research record](https://agris.fao.org/search/en/providers/123818/records/6748c8567625988a3720c1db) |
| Fresh lemongrass, pandan, Vietnamese basil | 3 | UPLB reported a 3–4-day saleability period in open storage at 10–32°C; basil evidence is specific to Vietnamese basil. [Study](https://www.ukdr.uplb.edu.ph/journal-articles/5969/) |
| Whole eggplant (Mucho) | 5 | UPLB ambient control at about 28.9°C became unmarketable after 5 days. [Abstract, p. 29](https://iceat.uplb.edu.ph/wp-content/uploads/2025/06/iCEAT-2025-Book-of-Abstracts.pdf) |

Profile matching normalizes capitalization, spaces, and punctuation, then uses
the catalogue’s explicit English and Filipino aliases. It does not guess from
produce categories or fuzzy name matches. Bare “Tomato” intentionally uses the
mature-green default; mangoes and Saba bananas require a green/mature-green
name, and sweet peppers require an explicit green form. Explicit conflicting
forms, such as ripe tomatoes, use a three-day fallback when no exact catalogue
profile matches. This keeps every received batch dated without requiring a
staff estimate.

Every new receipt or harvest creates its own batch. The database uses the
recorded harvest date when linked to a harvest record; otherwise it uses the
Philippine calendar date of receipt and labels the age approximation. New
opening stock uses its recorded creation date and is also labelled
approximate. Historical on-hand batches with no receipt history use the date
the automation migration is applied as an assumed stock date, with an audit
entry and no quantity change. This is a display assumption, not a recovered
receipt date. New adjustments or reversals without a known origin remain
unestimated. Existing supported profiles can be assigned automatically with
an audit entry without changing batch quantities.

The database stores a profile and reference snapshot with each batch and
returns movement, batch, estimate date, allocation, and source details through
one read view used by both clients. Item renames and catalogue edits do not
change existing snapshots. Issues use FIFO by default; staff can expand
“Choose batch” when a specific batch was affected. Voiding a sale restores its
original batch allocations when available.

Unmatched product names use a three-day application fallback so each receipt
has an estimated date. This is not a universal shelf-life finding: the
PhilMech reference reports three-to-four days for selected vegetables in a
non-refrigerated evaporative cooler, while the fallback uses three days for
any unmatched item as a practical default. Exact catalogue profiles take
precedence. [PhilMech reference](https://www.philmech.gov.ph/?action=storyFullView&page=stories&recordID=NE08010151&storyCateg=News&storyMonth=1&storyYear=2008)

Countdowns use Philippine calendar dates. The interface says “About N days
remaining,” “Estimate reached today,” or “Past estimate—inspect stock.” Batches
within two days are highlighted; depleted batches say “Fully used.” Each
estimate says: “Unrefrigerated storage assumed. Shelf-life estimate only.
Actual condition depends on handling, maturity, and storage.”

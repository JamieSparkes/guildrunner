**GUILDRUNNER**

*Game Design Document*

Version 0.2  ·  Post Design Review

# **1\. Overview**

Guildrunner is a single-player guild management game set in a low fantasy medieval world. The player oversees a settlement of heroes-for-hire — a ruined castle being slowly rebuilt into a formidable guild hall. People from all walks of life bring their problems to the player's door: merchants, peasants, lords, and criminals. The player assigns heroes to contracts, equips them, sets their level of commitment, and watches events unfold through a real-time feed — or dispatches them and gets on with other business.

The game is mostly serious in tone, with occasional dry humour. Magic exists in the world but heroes do not wield it — rare artefacts with magical properties exist as rewards for difficult missions. The world is grounded and worn-in, with no chosen-one narrative: the guild is simply a group of professionals trying to keep the lights on.

*"You are not the hero. You are the one who sends the heroes."*

# **2\. Core Design Pillars**

## **2.1 The Guild is Your World**

The player never leaves the guild. There is no world map to explore. The world comes to the player through contracts, messengers, and the consequences of their decisions. All the player's attention and investment goes into the castle and the people who live in it.

## **2.2 Heroes Are People**

Heroes have names, personalities, dialogue, and histories. They form bonds and tensions with each other. They grow attached to their gear. When they die, it is a moment — not a statistic. The no-levels system ensures that a veteran hero is irreplaceable not because of accumulated numbers, but because of who they have become.

## **2.3 Every Decision Has Weight**

The world is reactive. Taking a contract from the criminal underworld affects how the Church views the guild. Ignoring an important merchant has consequences. Killing a cult leader means the cult remembers. The player is always building or burning reputation, and the siege at the end of the game is a reckoning for everything they have done.

## **2.4 Management is the Game**

Guildrunner is not an action game with management bolted on. The management layer is the primary experience. The auto-resolve feed — a real-time narrative of missions playing out across multiple heroes simultaneously — is the main mode of play. Direct-play missions are a planned post-launch feature.

# **3\. Setting & Tone**

## **3.1 World**

The game takes place in a low fantasy medieval European world — knights, feudal lords, castles, trade routes, and a Church with political power. Magic exists at the edges: in old ruins, cursed artefacts, and creatures that don't quite belong to the natural world. Heroes do not cast spells. Wizards are rare figures who appear as quest-givers, not party members.

## **3.2 The Guild's Location**

The guild occupies a fixed location — a ruined castle on the edge of a populated region. The player does not choose or change this location. The surrounding world is abstract: factions, settlements, and mission sites exist as concepts rather than places on a map. Distance to a mission site is expressed mechanically as the number of days a hero is away, not as geography.

## **3.3 Tone**

The tone is mostly serious. The world has poverty, violence, political corruption, and moral ambiguity. The guild takes hard jobs because hard jobs pay. That said, the game is not relentlessly grim — heroes have dry wit, contracts occasionally have absurd premises, and the cast of recurring characters who bring work to the guild includes some genuinely odd personalities. The humour is earned, not forced.

## **3.4 Magic & Artefacts**

Magic is present but not wielded. Heroes fight with steel. Artefacts — rare items found or received as mission rewards — may carry unexplained properties: a sword that seems to know where to strike, armour that grows cold in the presence of danger. These are exceptional items with exceptional effects. They are not explained, only experienced. A full magic system with caster heroes is out of scope for launch and flagged as a post-launch design space.

# **4\. The Guild Hub**

## **4.1 Physical Presentation**

The guild hub is a hand-illustrated 2D scene of the castle, presented in a style similar to Darkest Dungeon — a fixed side-on or slight isometric perspective that the player clicks around to navigate. Buildings and areas of the castle are interactive. As the player constructs and upgrades buildings, the scene visually changes: ruined walls become functional structures, empty courtyards gain forges and training grounds.

*"The castle should feel like it's waking up. The difference between day one and a fully upgraded guild should be immediately visible."*

## **4.2 Buildings**

There are six buildings at launch, each with two upgrade tiers: Basic (Tier 1\) and Improved (Tier 2). All buildings begin as ruins and must be constructed before they function. The visual state of each building in the hub scene reflects its current tier.

| Building | Tiers | Tier 1 Function | Tier 2 Function |
| :---- | :---- | :---- | :---- |
| Barracks | 2 | Houses up to 6 heroes; enables basic recruitment | Houses up to 12 heroes; unlocks legendary hero recruitment |
| Forge | 2 | Repairs gear after missions | Repairs and improves gear; unlocks rare quality upgrades |
| Infirmary | 2 | Reduces injury recovery by 1 day | Reduces recovery by 2 days; prevents minor injuries becoming serious |
| Training Grounds | 2 | Heroes can train between missions; slow attribute growth | Faster attribute growth; unlocks specific trait training |
| Tavern / Hall | 2 | Heroes recover morale faster; occasional dialogue events | Unlocks hero bonding events; provides one daily intervention token |
| Gatehouse / Walls | 2 | Reduces siege casualties; enables basic defence events | Significantly improves siege defence; unlocks wall events during raids |

## **4.3 Day/Night Structure**

Time advances in turns. Each turn represents one day. The player manually advances the day when they are ready. The day has two distinct phases:

* **Morning —** Morning: New contracts are delivered to the guild board. Messengers arrive with important jobs. The player reviews the board, assigns heroes, manages gear and the buildings, and advances the day.

* **Night —** Night: Occasional surprise events occur — a distress signal from a captured hero, an attack warning, an unexpected visitor. Night events are rarer and more consequential than morning contract delivery.

## **4.4 Persistent UI Elements**

A small amount of information is always visible on the hub screen without opening any menus: the current day, the gold counter, the number of heroes available vs. on missions, and a brief notification if anything requires attention. A full log — mission results, faction changes, hero events — is accessible via a dedicated button and can be filtered by category.

# **5\. Heroes**

## **5.1 Roster & Recruitment**

The player begins with three hand-authored starting heroes, each with a distinct archetype and personality. The roster size is capped by the Barracks building — Tier 1 supports up to six heroes, Tier 2 supports up to twelve. There is no hard global cap; housing is the only limit.

New heroes are recruited through several routes:

* A hiring board at the guild, refreshed periodically, offering procedurally generated heroes available for coin.

* Local lords and faction contacts who occasionally offer heroes as rewards or referrals.

* Rescued heroes encountered during missions who may choose to join the guild.

* Distress signals from independent adventurers who can be saved and recruited.

## **5.2 Archetypes**

All heroes belong to one of four archetypes, which define their attribute spread and the types of missions they perform well on. Archetypes are not rigid classes — a Fighter who has spent years doing stealth missions will accumulate stealth traits over time — but they determine where a hero starts.

| Archetype | Primary Stats | Best Mission Types | Weakness |
| :---- | :---- | :---- | :---- |
| Fighter | Strength, Resilience | Eliminate, Defend, Escort | Poor at stealth; slow on long-range missions |
| Rogue | Agility, Stealth | Retrieve, Explore, Eliminate (targeted) | Low resilience; struggles in direct combat |
| Ranger | Agility, Strength | Explore, Escort, Eliminate | Average at everything; no standout weakness |
| Support | Resilience, Leadership | Escort, Defend; boosts squad missions | Weak solo; needs team to shine |

## **5.3 Procedural vs. Legendary Heroes**

Most heroes are procedurally generated from archetype templates — names drawn from a pool, attributes rolled within archetype ranges, a starting personality type assigned, and a brief bio generated from a template library. Each procedural hero is distinct enough to feel like a person.

Legendary heroes are hand-authored characters with fixed names, backstories, specific traits, and unique dialogue. They appear rarely — through specific mission chains, faction rewards, or rescue events. They are memorable by design and carry narrative weight that procedural heroes cannot.

## **5.4 Personality & Character**

Each hero has a personality type — a brief descriptor visible on their stats screen (e.g. Stoic, Reckless, Loyal, Cynical). This type shapes the flavour text generated for their mission feed entries and their occasional dialogue lines in the guild hub. A Reckless hero's feed entry for the same ambush will read differently to a Stoic hero's.

Heroes occasionally speak in the guild — short lines that appear in the hub scene or the log when resting, training, or reacting to events. These are contextual and non-intrusive: a hero back from a hard mission might have a line about needing a drink; two heroes with a bond might exchange words in the tavern.

## **5.5 Bonds & Tensions**

Some heroes have preset relationships — a bond (mutual respect, shared history, close friendship) or a tension (rivalry, old grievance, conflicting values). These are defined in the hero's authored or generated profile and have light mechanical effects:

* Bonded heroes on the same mission receive a small morale bonus and may generate shared feed events.

* Heroes with a tension on the same mission may generate friction events, and one may perform slightly below their usual standard.

* Bonds and tensions are visible on the hero detail screen with a brief flavour description.

## **5.6 Hero Death**

Hero death is permanent. When a hero dies on a mission, the auto-resolve feed pauses on a dedicated card: the hero's portrait, their name, a short epitaph drawn from their history and personality, and the cause of death. The game does not continue until the player dismisses this screen. The death is then logged permanently in the guild's history.

*"Ser Aldric Vane — Fighter. 14 missions. Killed defending the merchant road, outnumbered three to one. He did not retreat."*

## **5.7 Gear Attachment**

Heroes who find or earn significant gear on missions may become attached to it. This is flagged on the item in the loadout screen. Removing a bonded item from a hero carries a morale penalty; in rare cases, particularly attached heroes may refuse, argue, or temporarily reduce their performance. Legendary heroes are more likely to form strong attachments. The player must weigh whether re-equipping a hero is worth the cost.

## **5.8 No Levels**

Heroes do not have experience points or level numbers. Progression is expressed through traits — discrete bonuses acquired after significant events (completing a certain number of missions, surviving near-death, completing a specific mission type repeatedly). A veteran fighter does not have a higher number; she has Composed Under Fire, Ambush Instinct, and a reputation that other heroes whisper about. Trait acquisition is visible and legible, but never feels like a grind.

# **6\. Missions & Contracts**

## **6.1 The Contract Board**

New contracts arrive each morning when the player advances the day. Standard contracts appear on a physical noticeboard in the guild hub scene — the player clicks the board to open a list and review them. Important contracts — from powerful factions, with significant consequences, or tied to a quest chain — are delivered by a messenger who appears in the hub scene and must be spoken to. This distinction naturally signals which jobs deserve attention.

## **6.2 Mission Types**

| Type | Description | Best Hero |
| :---- | :---- | :---- |
| Eliminate | Find and kill a specific target | Fighter or Rogue depending on approach required |
| Retrieve | Steal or recover a specific item | Rogue; Ranger for wilderness retrieval |
| Escort | Keep a person or cargo safe in transit | Fighter or Support; benefits from squad |
| Explore | Map or investigate an unknown location | Ranger or Rogue; stealth helps in unknown territory |
| Defend | Hold a location or protect a person over time | Fighter or Support; resilience is key |

## **6.3 Mission Duration & Distance**

Missions take a number of days to complete, during which assigned heroes are unavailable for other work. Duration is determined by two factors: the base complexity of the mission type (1–3 days for simple jobs, up to 5 for major ones) and the distance of the mission location from the guild (expressed as additional travel days, \+0 to \+2). Distance is stated on the contract brief — "two days ride to the north" is a mechanical fact, not just flavour.

## **6.4 Contract Consequences**

Contracts carry a consequence flag — Standard or Consequential. Standard contracts expire quietly if ignored or declined; the client moves on and no further action is taken. Consequential contracts — typically those from named factions, tied to quest chains, or flagged as urgent — result in a reputation hit with the relevant faction if ignored, and may trigger a direct consequence event (an assassin, a threatening letter, a withheld payment on future contracts).

The severity of the consequence scales with the importance of the contract and the current reputation standing with the client faction. A Trusted faction will give the player the benefit of the doubt; an Unknown faction will take a slight as confirmation of the guild's unreliability.

## **6.5 Squad Missions**

Some missions require or benefit from multiple heroes. The contract brief states the minimum and recommended squad size. Sending more heroes than the minimum makes the mission easier but leaves them unavailable for other work. The player must weigh the benefit of an easy success against the cost of having those heroes off the board. As the game progresses and contract volume increases, this becomes a genuine strategic constraint.

## **6.6 Night Events**

Occasionally, an event arrives at night rather than in the morning. Night events are unscheduled and more consequential: a distress signal from a captured hero, a warning of an imminent attack, an anonymous tip about a hidden treasure, or an uninvited visitor at the gate. They cannot be planned for and require an immediate decision.

# **7\. The Auto-Resolve Feed**

## **7.1 Overview**

When heroes are dispatched on missions, the player watches events unfold through the Auto-Resolve Feed — a real-time narrative panel that reports what is happening across all active missions simultaneously. This is the primary moment-to-moment experience of the game and the feature that most distinguishes Guildrunner from similar titles.

## **7.2 Multi-Mission Display**

Each active mission has its own colour-coded feed column, inspired by Football Manager's match engine. If three heroes are on three different missions simultaneously, three colour-coded feeds run side by side, each updating independently. The player's attention naturally flows between them as events of varying severity arrive. A quiet mission sits in the background; a mission going wrong demands immediate focus.

*"Hana \[BLUE\]  —  Hana locates the cave entrance."*

*"Aldric \[RED\]  —  Aldric is outnumbered. The merchant road is not clear."*

*"Pip \[GREEN\]  —  Pip retrieves the package. Beginning return."*

## **7.3 Event Presentation**

Each feed entry consists of text accompanied by the hero's portrait, which reacts to the event type (neutral, cautious, wounded, triumphant). For significant moments — a kill, a near-death, an artefact found, a death — a brief illustrated panel appears above the feed text, giving the moment visual weight without interrupting flow. Minor events are text-only.

## **7.4 Player Intervention**

The player is not entirely passive during the feed. At certain points in a mission, an intervention prompt appears — a moment where the player can adjust the hero's commitment level in response to new information. This might be triggered by a wound, an unexpected enemy count, or a branching decision point. Each day, the player has a limited number of interventions available, determined by the Tier of the Tavern building. Tier 1 Tavern provides one intervention per day; Tier 2 provides two.

Interventions are the player's main active lever during the feed. Changing commitment from Use Judgement to Come Home Safe when a hero is wounded may save their life; changing to At Any Cost when the objective is close may secure a crucial success at risk of injury. Using all intervention tokens early in the day on low-priority missions means there are none left if something goes badly later.

## **7.5 Commitment Levels**

Each hero is assigned a commitment level before dispatch. This shapes how aggressively they pursue the objective and how quickly they retreat when things go wrong:

| Level | Effect on Outcome | Effect on Injury / Death |
| :---- | :---- | :---- |
| Come Home Safe | Reduces success probability by \~25% | Halves injury chance; hero retreats early |
| Use Judgement | Baseline | Standard injury and death rates |
| At Any Cost | Increases success probability by \~25% | Doubles injury chance; hero will not retreat |

# **8\. Economy**

## **8.1 Gold**

Gold is the primary resource and is always visible in the hub UI. Contracts pay on completion — partial success pays a reduced amount, failure pays nothing. The economy is designed to feel moderate: the player should occasionally face a tough spending decision, but gold is not the primary scarce resource. Heroes and their availability are.

## **8.2 Upkeep**

Each hero costs a small weekly upkeep — paid automatically at the start of each week. The amount is modest and should not be the primary cause of difficulty; it exists to create a baseline incentive to keep the guild active and to make a large idle roster feel slightly wasteful. Upkeep is visible on the economy panel in the log screen.

## **8.3 Gold Sinks**

The meaningful gold decisions in the game are:

* Healing injured heroes — the infirmary speeds recovery, but full treatment is expensive. Leaving a hero to recover naturally is free but slow.

* Training heroes — using the Training Grounds costs gold per session. Players must choose which heroes to invest in.

* Building and upgrading — construction costs increase significantly at Tier 2\.

* Hiring new heroes — quality heroes from the board command a recruitment fee.

* Hiring mercenary support for the siege — if allies are insufficient, mercenaries fill the gap at significant cost.

## **8.4 Gear**

Gear is acquired through two routes. Mission loot: heroes occasionally bring back items found during a mission — weapons, armour, and occasionally rare artefacts. These are automatically added to the guild's inventory. Purchase: a travelling merchant visits the guild periodically and offers items for sale, ranging from common gear to uncommon pieces. The Forge does not create gear; it repairs damaged equipment after missions and, at Tier 2, can improve an existing item's quality by one tier.

# **9\. Factions & Reputation**

## **9.1 Factions**

Five factions exist at launch, each offering different contract types, different rewards, and different consequences for angering or impressing them:

| Faction | Type | Contracts Offered | Hostile Action |
| :---- | :---- | :---- | :---- |
| The Crown | Nobility / State | Eliminate, Escort, Defend | Knights or soldiers attack the guild |
| The Church | Religious | Explore, Eliminate (undead/cultists), Escort | Inquisitors investigate; deny guild access to healing |
| Merchants | Trade | Retrieve, Escort, Defend | Assassins hired; contracts dry up |
| Underworld | Criminal | Eliminate, Retrieve (theft), Explore | Sabotage events; night raids on the guild |
| Common Folk | Peasantry | Eliminate (beasts), Explore, Defend (villages) | Reputation damage only; no direct attacks |

## **9.2 Reputation Tiers**

Reputation with each faction is expressed through five descriptive tiers, not a raw number. The player sees the tier label and a brief description of how the faction currently views the guild. An underlying numeric value drives the system but is not directly displayed.

| Tier | Label | Effect |
| :---- | :---- | :---- |
| 5 (highest) | Honoured | Best contracts offered; faction provides siege aid if asked |
| 4 | Trusted | Consistent contracts; small reward bonuses; benefit of the doubt on failures |
| 3 | Neutral | Standard contracts; no bonuses or penalties |
| 2 | Unknown | Occasional contracts; no trust established yet |
| 1 (lowest) | Enemy | No contracts offered; active hostile consequences |

## **9.3 Faction Independence**

Factions do not interact with each other mechanically. Each faction's reputation changes independently based solely on the player's actions. There is no inter-faction war system or diplomatic relationship network at launch. A player can be Honoured by the Crown and Trusted by the Underworld simultaneously — the world does not force a conflict between them. Individual contracts may ask the player to act against another faction's interests, but this is framed as a choice, not an enforced narrative.

# **10\. The Siege**

## **10.1 Structure**

The siege is the game's climactic event, but it is not the game's only combat threat. The structure has three phases:

* **First Raid —** A first small raid in the mid-game introduces the defence mechanic and shows the player what a guild attack looks like. Stakes are low; this is a teaching moment.

* **Second Raid —** A second, larger raid escalates the threat and signals that the final siege is coming. This raid is winnable but not trivial — players who have neglected the Gatehouse will feel it.

* **The Final Siege —** The final siege is a major event. The full force of the opposing coalition arrives. Preparation over the course of the game determines whether the guild survives intact.

## **10.2 How the Siege Is Played**

The siege uses an enhanced version of the auto-resolve feed. Events are more dramatic, more frequent, and more consequential than standard mission feeds. Hero portraits appear larger at key moments. Deaths during the siege carry the same full memorial card as mission deaths, but within the flow of an ongoing battle. The feed continues around a hero's death — the fight does not stop.

The outcome of the siege is determined by preparation factors evaluated at the start of the event: the Gatehouse tier, the number and quality of heroes defending, allied faction forces present, hired mercenaries, and the overall level of enemy strength (determined by accumulated hostilities across the game). The feed then narrates a plausible sequence of events consistent with the rolled outcome.

## **10.3 The Siege Leader**

The identity of the siege leader is not yet finalised. The leading candidate is a coalition model: the primary force is funded and led by whichever faction or factions the player has most antagonised over the course of the game. This makes the siege feel like a direct consequence of the player's decisions rather than a pre-scripted villain arrival. Full design is deferred pending narrative development.

## **10.4 Allies & Mercenaries**

Factions at Honoured or Trusted standing can be called upon to provide support troops for the siege — a contingent of soldiers or operatives who contribute to the defence roll. Factions at lower standings cannot be called upon. If allied support is insufficient or unavailable, the player can hire mercenaries for gold, providing a reliable but expensive fallback.

# **11\. Narrative & Structure**

## **11.1 The Guild Master**

The player character is a silent guild master — present in the world, referenced by heroes and clients, but without a fixed identity. The player projects onto this figure. There are no dialogue choices for the guild master and no voiced lines. Personality is expressed through decisions, not cutscenes.

## **11.2 Story Shape**

The narrative is atmosphere-first rather than plot-first. The world has history, factions with competing agendas, and a slow-building sense that something is coming — but there is no chosen-one arc or central villain reveal at launch. The story emerges from the contracts the player takes, the heroes they invest in, and the enemies they make. Quest chains exist as longer narrative threads connecting several related contracts, providing momentum and context without demanding the player follow a single throughline.

## **11.3 Game Structure**

### **Early Game (Days 1–20)**

The guild is a ruin. Three heroes, a handful of contracts, and very little money. The player learns the systems without pressure. Missions are simple; the contract board is small. The first building goes up. The first hero develops a trait. The pace is forgiving by design.

### **Mid Game (Days 21–60)**

The roster grows. The contract board fills up faster than it can be serviced. Quest chains begin — longer narrative threads that unfold across several related missions and introduce the major factions more deeply. The two raid events occur in this phase. The player becomes aware that a larger threat is forming and must start preparing.

### **The Siege (Day 60–80, approximate)**

The final siege arrives. Everything the player has built, every ally cultivated, every hero kept alive feeds into this moment. Surviving with the roster largely intact is the measure of success.

### **Post-Siege (Day 80+)**

The immediate crisis is over. The game continues indefinitely — a mix of standard contracts, occasional longer quest chains, and the ongoing business of the guild. The world is shaped by what happened during the main game. This phase is designed for expansion through post-launch content.

## **11.4 Replayability**

Each new game draws from randomised hero pools and procedurally generated contract sequences, ensuring no two playthroughs feel identical. The hand-authored quest chains and legendary heroes appear in each run but at different points and in different orders. The starting heroes are fixed — the same three characters anchor every playthrough — but the supporting cast is always different.

# **12\. Difficulty & Player Options**

## **12.1 Mode Selection**

At the start of a new game, the player chooses between two modes:

* **Standard —** The default experience. Autosave on each day advance and after mission results. Hero death is permanent but the game can be reloaded to the last autosave. Aimed at players who want to feel the weight of decisions without the full commitment of ironman.

* **Ironman —** One save file, updated automatically. No manual saves. Hero death is final with no recourse. Intended for players who want every decision to carry maximum consequence.

## **12.2 No Difficulty Slider**

There is no easy/normal/hard difficulty setting. The game has one designed difficulty level. Ironman mode is the only formal difficulty modifier. Players who find the game too challenging can lean on lower commitment levels, smaller squads on simpler missions, and more conservative guild management. The systems provide natural self-adjustment without a difficulty menu.

# **13\. Onboarding**

The game does not open with a tutorial. The player is placed in the guild on day one with three heroes and a small number of contracts on the board. Contextual tooltips appear the first time a new system is interacted with — hovering over a commitment level selector shows a brief explanation; clicking the contract board for the first time shows a hint about the noticeboard vs. messenger distinction.

Beyond contextual hints, the player learns by doing. The first few days of the game are designed to be forgiving enough that mistakes don't end runs — contracts are simple, heroes are unlikely to die, and the consequences of sub-optimal decisions are mild. The game assumes players who enjoy management games will want to discover the systems through play.

*— End of Document —*
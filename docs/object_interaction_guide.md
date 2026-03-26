# Object Interaction Guide

Auto-generated map of current object interactions across autoloads, systems, UI scripts, scene scripts, utilities, and models.

## 1) High-level interaction graph

```mermaid
graph TD
    BuildingManager["BuildingManager\n(Autoload)"]
    ContractQueue["ContractQueue\n(Autoload)"]
    EventBus["EventBus\n(Autoload)"]
    FactionManager["FactionManager\n(Autoload)"]
    FeedManager["FeedManager\n(Autoload)"]
    GameManager["GameManager\n(Autoload)"]
    GuildManager["GuildManager\n(Autoload)"]
    HeroManager["HeroManager\n(Autoload)"]
    ItemManager["ItemManager\n(Autoload)"]
    MissionManager["MissionManager\n(Autoload)"]
    TimeManager["TimeManager\n(Autoload)"]
    UIManager["UIManager\n(Autoload)"]
    GuildHubScene["GuildHubScene\n(Scene Script)"]
    BuildingEffectProcessor["BuildingEffectProcessor\n(System)"]
    InjuryResolver["InjuryResolver\n(System)"]
    MissionResolver["MissionResolver\n(System)"]
    RelationshipModifier["RelationshipModifier\n(System)"]
    BuildingScreen["BuildingScreen\n(UI Screen)"]
    ContractBoardScreen["ContractBoardScreen\n(UI Screen)"]
    FeedScreen["FeedScreen\n(UI Screen)"]
    HeroDetailScreen["HeroDetailScreen\n(UI Screen)"]
    HeroRosterScreen["HeroRosterScreen\n(UI Screen)"]
    MainMenuScreen["MainMenuScreen\n(UI Screen)"]
    MissionBriefingScreen["MissionBriefingScreen\n(UI Screen)"]
    DataLoader["DataLoader\n(Utility)"]
    BuildingManager --> BuildingEffectProcessor
    BuildingManager --> DataLoader
    BuildingManager --> EventBus
    BuildingManager --> GuildManager
    BuildingManager --> TimeManager
    ContractQueue --> DataLoader
    ContractQueue --> EventBus
    ContractQueue --> TimeManager
    FactionManager --> EventBus
    FeedManager --> DataLoader
    FeedManager --> EventBus
    FeedManager --> GuildManager
    FeedManager --> TimeManager
    GameManager --> ContractQueue
    GameManager --> DataLoader
    GameManager --> EventBus
    GameManager --> FeedManager
    GameManager --> GuildHubScene
    GameManager --> GuildManager
    GameManager --> HeroManager
    GameManager --> MissionManager
    GameManager --> TimeManager
    GameManager --> UIManager
    GuildManager --> EventBus
    GuildManager --> HeroManager
    GuildManager --> TimeManager
    HeroManager --> EventBus
    HeroManager --> GuildManager
    HeroManager --> InjuryResolver
    MissionManager --> DataLoader
    MissionManager --> EventBus
    MissionManager --> FeedManager
    MissionManager --> GuildManager
    MissionManager --> HeroManager
    MissionManager --> InjuryResolver
    MissionManager --> MissionResolver
    MissionManager --> TimeManager
    TimeManager --> ContractQueue
    TimeManager --> EventBus
    TimeManager --> GuildManager
    UIManager --> BuildingScreen
    UIManager --> ContractBoardScreen
    UIManager --> FeedScreen
    UIManager --> HeroDetailScreen
    UIManager --> HeroRosterScreen
    UIManager --> MissionBriefingScreen
    GuildHubScene --> ContractQueue
    GuildHubScene --> GameManager
    GuildHubScene --> TimeManager
    GuildHubScene --> UIManager
    BuildingEffectProcessor --> GuildManager
    InjuryResolver --> HeroManager
    MissionResolver --> DataLoader
    MissionResolver --> RelationshipModifier
    BuildingScreen --> BuildingManager
    BuildingScreen --> EventBus
    BuildingScreen --> GuildManager
    BuildingScreen --> UIManager
    ContractBoardScreen --> ContractQueue
    ContractBoardScreen --> EventBus
    ContractBoardScreen --> UIManager
    FeedScreen --> EventBus
    FeedScreen --> FeedManager
    FeedScreen --> TimeManager
    FeedScreen --> UIManager
    HeroDetailScreen --> HeroManager
    HeroDetailScreen --> UIManager
    HeroRosterScreen --> HeroDetailScreen
    HeroRosterScreen --> HeroManager
    HeroRosterScreen --> UIManager
    MainMenuScreen --> GameManager
    MissionBriefingScreen --> ContractQueue
    MissionBriefingScreen --> HeroManager
    MissionBriefingScreen --> MissionManager
    MissionBriefingScreen --> UIManager
```

## 2) Per-object dependency map

| Object | Type | Interacts with |
|---|---|---|
| `BuildingData` | Model | GuildState |
| `BuildingEffectProcessor` | System | BuildingData, GuildManager |
| `BuildingManager` | Autoload | BuildingData, BuildingEffectProcessor, DataLoader, EventBus, GuildManager, TimeManager |
| `BuildingScreen` | UI Screen | BuildingManager, BuildingSlot, EventBus, GuildManager, UIManager |
| `BuildingSlot` | UI Component | BuildingData, BuildingManager, EventBus, GuildManager, TimeManager |
| `ContractBoardScreen` | UI Screen | ContractCard, ContractData, ContractQueue, EventBus, UIManager |
| `ContractCard` | UI Component | ContractData, Enums |
| `ContractData` | Model | ContractQueue, Enums |
| `ContractQueue` | Autoload | ContractData, DataLoader, EventBus, TimeManager |
| `DataLoader` | Utility | BuildingData, ContractData, Enums, FactionData, HeroData, HeroRelationship, ItemData |
| `EventBus` | Autoload | Enums |
| `FactionData` | Model | Enums, FactionManager |
| `FactionManager` | Autoload | EventBus |
| `FeedEntry` | UI Component | FeedEvent |
| `FeedManager` | Autoload | DataLoader, Enums, EventBus, FeedEvent, GuildManager, TimeManager |
| `FeedScreen` | UI Screen | EventBus, FeedEntry, FeedEvent, FeedManager, InterventionPrompt, TimeManager, UIManager |
| `GameManager` | Autoload | ContractQueue, DataLoader, Enums, EventBus, FeedManager, GuildHubScene, GuildManager, HeroData, HeroManager, MissionManager, TimeManager, UIManager |
| `GuildHubScene` | Scene Script | ContractQueue, Enums, GameManager, TimeManager, UIManager |
| `GuildManager` | Autoload | Enums, EventBus, GuildState, HeroManager, TimeManager |
| `GuildState` | Model | GuildManager |
| `HUDBar` | Object | EventBus, GuildManager, HeroManager, TimeManager |
| `HeroData` | Model | Enums, HeroRelationship |
| `HeroDetailScreen` | UI Screen | Enums, HeroData, HeroManager, HeroRelationship, UIManager |
| `HeroManager` | Autoload | Enums, EventBus, GuildManager, HeroData, InjuryResolver |
| `HeroPortraitCard` | UI Component | Enums, HeroData, HeroRosterScreen, MissionBriefingScreen |
| `HeroRelationship` | Model | Enums |
| `HeroRosterScreen` | UI Screen | Enums, HeroData, HeroDetailScreen, HeroManager, HeroPortraitCard, UIManager |
| `InjuryResolver` | System | Enums, HeroData, HeroManager |
| `InterventionPrompt` | UI Component | Enums, EventBus, GuildManager, MissionManager |
| `ItemData` | Model | Enums |
| `MainMenuScreen` | UI Screen | GameManager |
| `MissionBriefingScreen` | UI Screen | ContractData, ContractQueue, Enums, HeroData, HeroManager, HeroPortraitCard, MissionManager, UIManager |
| `MissionManager` | Autoload | ContractData, DataLoader, Enums, EventBus, FeedManager, GuildManager, HeroData, HeroManager, InjuryResolver, MissionResolver, TimeManager |
| `MissionResolver` | System | ContractData, DataLoader, Enums, HeroData, ItemData, RelationshipModifier |
| `RelationshipModifier` | System | HeroData, HeroRelationship |
| `TimeManager` | Autoload | ContractQueue, Enums, EventBus, GuildManager |
| `UIManager` | Autoload | BuildingScreen, ContractBoardScreen, FeedScreen, HeroDetailScreen, HeroRosterScreen, MissionBriefingScreen |
| `enums` | Object | Enums |

## 3) EventBus signal interaction matrix

| Signal | Emitted by | Consumed via connect() by |
|---|---|---|
| `day_advanced` | TimeManager | BuildingManager, BuildingSlot, GuildManager, HUDBar, HeroManager, MissionManager |
| `night_began` | TimeManager | — |
| `week_advanced` | TimeManager | — |
| `hero_dispatched` | MissionManager | HUDBar |
| `hero_returned` | MissionManager | HUDBar |
| `hero_wounded` | HeroManager | HUDBar |
| `hero_killed` | HeroManager | HUDBar |
| `hero_captured` | HeroManager | HUDBar |
| `hero_trait_acquired` | — | — |
| `hero_morale_changed` | GuildManager | — |
| `contract_available` | ContractQueue | ContractBoardScreen |
| `contract_accepted` | MissionManager | ContractBoardScreen |
| `contract_completed` | MissionManager | — |
| `contract_expired` | ContractQueue | — |
| `messenger_arrived` | — | — |
| `feed_event` | MissionManager | FeedManager |
| `feed_intervention_available` | FeedManager | FeedScreen |
| `intervention_used` | InterventionPrompt | FeedManager |
| `reputation_changed` | — | — |
| `faction_became_enemy` | — | — |
| `faction_became_ally` | — | — |
| `building_construction_started` | BuildingManager | BuildingSlot |
| `upgrade_built` | BuildingManager | BuildingSlot |
| `guild_attacked` | — | — |
| `gold_changed` | GuildManager | BuildingScreen, BuildingSlot, HUDBar |
| `state_changed` | GameManager | — |

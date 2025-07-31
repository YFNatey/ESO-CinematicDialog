# Cinematic Dialog - An Elder Scrolls Online Addon
Transform your questing experience into cinematic storytelling through immersive camera work and presentation.

## Context for Non-Elder Scrolls Players
Elder Scrolls Online features rich stories and dialogue where players interact with non-player characters (NPCs) through conversation trees. By default, these interactions use a first-person camera perspective with standard UI elements that can feel disconnected from the narrative experience. This addon transforms these moments into cinematic encounters inspired by popular single-player games. 

## The Vision: Environmental Storytelling Through Cinematography
In films, every element within the frame serves the narrative. The crackling hearth in a tavern, the weathered stone of ancient ruins, the subtle interactions between background characters — these elements collectively create emotional resonance and narrative depth. When a camera captures not just the speaker but the entire scene, it allows the environment itself to become a storyteller.
This approach transforms routine interactions into memorable cinematic moments.

## Features for Players
* **Cinematic Camera Control** 
* **Dialogue Layout Presets** from subtle repositioning to full screen centering
* **Dynamic Letterbox Bars** Adds optional black bars that automatically animate in during interactions
* **Custom font options**
* **Chunked Dialogue System** Presents NPC text in timed segments for more natural, paced conversations

## Technical Overview
* **Event-Driven Architecture:** 
Hooks into ESO's dialogue system through multiple event channels.

* **Dynamic UI State Management:** 
Maintains consistent state across different interaction types while preserving user preferences.

* **Text Processing** 
Uses text chunking with punctuation-aware timing algorithms.

* **Camera State Coordination**
Manages camera transitions without conflicting with ESO's existing camera systems.

## Implementation Highlights
* **Memory Persistence**
Utilises ZO_SavedVars for configuration management whilst handling version migration.

* **Modular Architecture Design**
Cleanly separated alogorithms for dialogue processing, camera management, UI manipulation, and user configuration.

* **Defensive Programming Patterns**
Extensive error handling and state validation to ensure stability across diverse gameplay scenarios.

This project represents my commitment to creating thoughtful, detail-oriented systems that enhance user experiences while respecting established narrative elements.

## Support

If you find this addon useful, consider supporting its development:
* [Ko-fi](https://Ko-fi.com/yfnatey)
* [PayPal](https://paypal.me/yfnatey)
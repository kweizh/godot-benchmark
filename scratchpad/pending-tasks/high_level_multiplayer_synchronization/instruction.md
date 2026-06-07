You are developing a fast-paced multiplayer arena game and need to synchronize game state across multiple connected clients.

You need to implement a GDScript for a player entity that configures a `MultiplayerSynchronizer` to automatically sync the player's `global_position` across the network. Additionally, implement an RPC method to broadcast a score update whenever a player scores a point, ensuring the update executes locally and on all peers.

**Constraints:**
- The score update function MUST use the `@rpc("any_peer", "call_local")` annotation.
- Position syncing must rely EXCLUSIVELY on `MultiplayerSynchronizer` configuration; do not manually send position data via RPCs.
- The script must assume the network peer and multiplayer authority are already established.
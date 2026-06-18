-- ModuleScript: ServerScriptService > GameState
-- Shared state table; all server scripts that require this get the same instance
return {
	current = "LOBBY",  -- "LOBBY" | "COUNTDOWN" | "SETUP" | "PLAYING" | "RESULTS"
}

extends RefCounted
## Arc-length resampled river the serpent swims along. Kept apart from the
## boss script: static state on a preloaded boss script pins the renderer's
## static mesh caches at exit.
static var cache:Dictionary={}

extends RefCounted
## One geometry contract for the paired HUD actions, in 412px stage coordinates.
const STAGE_WIDTH:=412.0
const MARKET_RECT:=Rect2(350,722,46,46)
const LAUNCH_RECT:=Rect2(STAGE_WIDTH-MARKET_RECT.end.x,MARKET_RECT.position.y,MARKET_RECT.size.x,MARKET_RECT.size.y)

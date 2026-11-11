extends RefCounted
## Original layered vector emblems, rasterized once at 3x. No font glyphs or
## generic line-icon substitutions; each family has its own material silhouette.
static var cache:Dictionary={}
const ART := {
	"power":'<path d="M18 13Q53 30 18 53L26 33Z" fill="url(#wood)" stroke="#493128" stroke-width="2"/><path d="M18 13L26 33 18 53" fill="none" stroke="#f9eac4" stroke-width="1.7"/><path d="M11 34L52 25M46 22L55 24 49 31" fill="none" stroke="url(#metal)" stroke-width="3"/><path d="M12 34L8 29 19 31M12 34L10 40 21 33" fill="#b1ddd8"/><path d="M27 28L32 31 28 37 23 35Z" fill="#f4cc76"/>',
	"arrow":'<path d="M17 52L40 25" stroke="#554032" stroke-width="6"/><path d="M17 51L41 23" stroke="url(#wood)" stroke-width="3"/><path d="M33 25L48 9 51 31 42 27 36 33Z" fill="url(#metal)" stroke="#304e5a" stroke-width="1.5"/><path d="M48 10L42 27 34 25" fill="#fff5d6"/><path d="M23 39L11 39 10 54 23 51 30 40" fill="url(#feather)" stroke="#365c61"/><path d="M12 51L27 40" stroke="#e8f5df" stroke-width="1.5"/>',
	"brick":'<path d="M10 40L20 17 36 12 53 30 45 51 24 55Z" fill="#4d6a64" stroke="#30473f" stroke-width="2"/><path d="M20 17L28 36 10 40M28 36L36 12 53 30 45 51Z" fill="#769286"/><path d="M28 36L37 23 48 31 41 44Z" fill="url(#gold)" stroke="#9b6b32"/><circle cx="22" cy="43" r="9" fill="url(#gold)" stroke="#996526" stroke-width="2"/><path d="M22 38V48M19 40L25 46M25 40L19 46" stroke="#93652d" stroke-width="1.4"/><path d="M35 18L38 22 35 26 32 22Z" fill="#fff2b9"/>',
	"draw":'<path d="M46 23A20 20 0 1 0 48 39" fill="none" stroke="#34565e" stroke-width="7"/><path d="M46 23A20 20 0 1 0 48 39" fill="none" stroke="url(#metal)" stroke-width="4"/><path d="M42 12L52 27 36 26Z" fill="url(#gold)"/><path d="M34 15L22 34 32 34 28 50 43 29 33 29Z" fill="url(#gold)" stroke="#9c7139"/><path d="M9 24H19M7 31H17M9 38H18" stroke="#b0d8d0" stroke-width="2"/>',
	"comboCap":'<path d="M14 30C1 21 19 8 29 18L40 29C52 39 40 54 30 45L24 39" fill="none" stroke="#5e492e" stroke-width="9"/><path d="M14 30C1 21 19 8 29 18L40 29C52 39 40 54 30 45L24 39" fill="none" stroke="url(#gold)" stroke-width="5"/><path d="M29 33L38 20C48 6 63 24 50 33L40 41" fill="none" stroke="url(#metal)" stroke-width="6"/><path d="M18 38L21 43 27 44 22 48 22 54 17 51 12 53 13 47 9 43 15 42Z" fill="#f6d482"/>',
	"slots":'<path d="M32 8L55 24 46 52H18L9 24Z" fill="#344b5d" stroke="#9b945e" stroke-width="1.6"/><path d="M32 15L17 27 23 45H41L47 27Z" fill="none" stroke="#94b9be"/><path d="M32 12L37 26 51 29 39 37 40 51 28 42 15 47 20 33 12 22 27 23Z" fill="url(#metal)"/><path d="M32 24L39 32 32 40 25 32Z" fill="url(#gold)"/><circle cx="32" cy="32" r="3" fill="#fff9d8"/>',
	"rerollCap":'<circle cx="32" cy="33" r="22" fill="#334f56" stroke="url(#gold)" stroke-width="3"/><circle cx="32" cy="33" r="17" fill="none" stroke="#97bab4"/><path d="M32 14L38 30 51 33 36 39 32 52 27 37 13 33 27 28Z" fill="url(#metal)"/><path d="M32 17L32 33 39 30Z" fill="url(#gold)"/><path d="M32 33L25 37 32 50Z" fill="#a67c43"/><circle cx="32" cy="33" r="4" fill="#fff0b3"/><path d="M28 7H36M32 4V10" stroke="#d7bf76" stroke-width="3"/>'
}

static func texture(key:String,tier:int) -> Texture2D:
	var id:=key+str(tier)
	if cache.has(id):return cache[id]
	var ornaments:=""
	for i in range(tier):ornaments+='<path d="M%d 57l2 2-2 2-2-2Z" fill="#f5d998"/>' % (32+(i*2-tier+1)*5)
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><defs><linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#fff0a8"/><stop offset=".48" stop-color="#e9ba62"/><stop offset="1" stop-color="#986532"/></linearGradient><linearGradient id="metal" x2="1" y2="1"><stop stop-color="#f0fff5"/><stop offset=".45" stop-color="#b4d9db"/><stop offset="1" stop-color="#4f8999"/></linearGradient><linearGradient id="wood" x2="1" y2=".7"><stop stop-color="#f3c587"/><stop offset=".55" stop-color="#ab754a"/><stop offset="1" stop-color="#6a4030"/></linearGradient><linearGradient id="feather" x2="1" y2="1"><stop stop-color="#def7dc"/><stop offset="1" stop-color="#609c9a"/></linearGradient></defs>'
	svg+=ART[key]+ornaments+'</svg>'
	var image:=Image.new();image.load_svg_from_string(svg,3.0)
	var result:=ImageTexture.create_from_image(image);cache[id]=result;return result

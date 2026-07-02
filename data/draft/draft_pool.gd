class_name DraftPool
extends RefCounted

## Holds the catalog of available DraftOptions and produces the per-round offer.
##
## Separates "what content exists" (the catalog, auto-discovered from a folder) from
## "how we pick" (weighted, no-duplicate roll). Dropping a new .tres into the options
## folder is enough to add it to the pool -- no wiring, no code changes anywhere.

const DEFAULT_OPTIONS_DIR: String = "res://data/draft/options/"

var options: Array[DraftOption] = []

## Build a pool by scanning a directory for every resource that is a DraftOption.
static func from_directory(dir: String = DEFAULT_OPTIONS_DIR) -> DraftPool:
	var pool: DraftPool = DraftPool.new()
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		push_warning("DraftPool: options directory not found: %s" % dir)
		return pool

	var seen: Dictionary = {}
	da.list_dir_begin()
	var file_name: String = da.get_next()
	while file_name != "":
		if not da.current_is_dir():
			# Exported builds may list "foo.tres.remap"; load the real resource path.
			var res_name: String = file_name
			if res_name.ends_with(".remap"):
				res_name = res_name.trim_suffix(".remap")
			if (res_name.ends_with(".tres") or res_name.ends_with(".res")) and not seen.has(res_name):
				seen[res_name] = true
				var res: Resource = ResourceLoader.load(dir.path_join(res_name))
				if res is DraftOption:
					pool.options.append(res)
		file_name = da.get_next()
	da.list_dir_end()
	return pool

## Return up to `count` distinct options, weighted by DraftOption.weight, filtered to
## those currently offerable. Returns fewer than `count` if not enough are available.
func roll(count: int) -> Array[DraftOption]:
	var candidates: Array[DraftOption] = []
	for option in options:
		if option != null and option.can_offer():
			candidates.append(option)

	var result: Array[DraftOption] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	while result.size() < count and not candidates.is_empty():
		var picked: DraftOption = _weighted_pick(candidates, rng)
		if picked == null:
			break
		result.append(picked)
		candidates.erase(picked)  # no duplicates within one offer
	return result

## Pick one option from `candidates` with probability proportional to its weight.
func _weighted_pick(candidates: Array[DraftOption], rng: RandomNumberGenerator) -> DraftOption:
	var total: float = 0.0
	for option in candidates:
		total += maxf(option.weight, 0.0)
	if total <= 0.0:
		return null

	var target: float = rng.randf() * total
	var accum: float = 0.0
	for option in candidates:
		accum += maxf(option.weight, 0.0)
		if target <= accum:
			return option
	return candidates.back()

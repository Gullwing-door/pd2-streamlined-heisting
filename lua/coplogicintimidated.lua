-- Tweak hostage rescue conditions
function CopLogicIntimidated.rescue_SO_verification(ignore_this, data, unit, ...)
	-- Less likely to free hostages during assault
	if not managers.groupai:state()._rescue_allowed and math.random() < 0.75 then
		return
	end

	if unit:movement():cool() then
		return
	end

	if not unit:base():char_tweak().rescue_hostages then
		return
	end

	if data.team.foes[unit:movement():team().id] then
		return
	end

	local objective = unit:brain():objective()
	if not objective or objective.type == "free" or not objective.area then
		return true
	end

	local nav_seg = data.unit:movement():nav_tracker():nav_segment()
	if objective.area.nav_segs[nav_seg] or unit:movement():nav_tracker():nav_segment() == nav_seg then
		return true
	end
end

-- Update this function with the changes made in CopLogicAttack._upd_aim
function TaserLogicAttack._upd_aim(data, my_data, reaction)
	if my_data.tasing then
		return
	end

	local focus_enemy = data.attention_obj
	local verified = focus_enemy and focus_enemy.verified
	local nearly_visible = focus_enemy and focus_enemy.nearly_visible

	local aim, shoot, expected_pos = CopLogicAttack._check_aim_shoot(data, my_data, focus_enemy, verified, nearly_visible)
	local tase = focus_enemy and focus_enemy.reaction == AIAttentionObject.REACT_SPECIAL_ATTACK

	if aim or shoot or tase then
		if verified or nearly_visible then
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)
				my_data.attention_unit = focus_enemy.u_key
			end
		elseif expected_pos then
			if my_data.attention_unit ~= expected_pos then
				CopLogicBase._set_attention_on_pos(data, expected_pos)
				my_data.attention_unit = expected_pos
			end
		end

		if not data.unit:anim_data().reload and not data.unit:movement():chk_action_forbidden("action") then
			if tase and not my_data.tasing and not focus_enemy.unit:movement():zipline_unit() then
				-- Stop moving when we're about to tase
				if not data.unit:movement():chk_action_forbidden("walk") then
					data.unit:brain():action_request({
						body_part = 2,
						type = "idle"
					})
				end

				local tase_action = {
					body_part = 3,
					type = "tase"
				}

				if data.unit:brain():action_request(tase_action) then
					my_data.tasing = {
						target_u_data = focus_enemy,
						target_u_key = focus_enemy.u_key,
						start_t = data.t
					}

					CopLogicAttack._cancel_charge(data, my_data)
					managers.groupai:state():on_tase_start(data.key, focus_enemy.u_key)
				end
			elseif not my_data.shooting and not my_data.tasing then
				my_data.shooting = data.unit:brain():action_request({
					body_part = 3,
					type = "shoot"
				})
			end
		end
	else
		if my_data.shooting or my_data.tasing then
			local success = data.unit:brain():action_request({
				body_part = 3,
				type = "idle"
			})
			if success then
				my_data.shooting = nil
				my_data.tasing = nil
			end
		end

		if my_data.attention_unit then
			CopLogicBase._reset_attention(data)
			my_data.attention_unit = nil
		end
	end

	CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
end


-- Update logic every frame
Hooks:PostHook(TaserLogicAttack, "enter", "sh_enter", function (data)
	data.brain:set_update_enabled_state(true)

	local my_data = data.internal_data
	my_data.detection_task_key = "TaserLogicAttack._upd_enemy_detection" .. tostring(data.key)
	CopLogicBase.queue_task(my_data, my_data.detection_task_key, TaserLogicAttack._upd_enemy_detection, data, data.t + 0.2)
end)

Hooks:PostHook(TaserLogicAttack, "_upd_enemy_detection", "sh__upd_enemy_detection", function (data, is_synchronous)
	if not is_synchronous then
		local my_data = data.internal_data
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, TaserLogicAttack._upd_enemy_detection, data, data.t + 0.2, data.important)
	end
end)

function TaserLogicAttack.update(data)
	local my_data = data.internal_data

	if my_data.has_old_action then
		CopLogicAttack._upd_stop_old_action(data, my_data)
		return
	end

	if my_data.tasing then
		CopLogicBase._report_detections(data.detected_attention_objects)
		return
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	local focus_enemy = data.attention_obj
	if not focus_enemy or focus_enemy.reaction < AIAttentionObject.REACT_AIM then
		TaserLogicAttack._upd_enemy_detection(data, true)
		return
	end

	CopLogicAttack._process_pathing_results(data, my_data)

	if data.attention_obj.reaction >= AIAttentionObject.REACT_COMBAT then
		CopLogicAttack._update_cover(data)
		CopLogicAttack._upd_combat_movement(data)
	end

	CopLogicBase._report_detections(data.detected_attention_objects)
end

function TaserLogicAttack.queued_update() end
function TaserLogicAttack.queue_update() end

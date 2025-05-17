-- This could use a re-do

if not DREAMS then
	Dreams.LoadDreams()
	return
end

DREAMS.MoveSpeed = 10
DREAMS.ShiftSpeed = 16
DREAMS.JumpPower = 200
DREAMS.Gravity = 200
DREAMS.Debug = 0

local math_cos = math.cos
local math_abs = math.abs
local IsValid = IsValid
local Vector = Vector
local Dreams = Dreams
local CurTime = CurTime

local room = DREAMS:AddRoom("1499", "models/dreams/scp1499/scp1499_dimension.mdl", "data_static/dreams/scp1499_dimension.dat", vector_origin)
room.MdlLighting = {0.5, 0.5, 0.6}
room.Lighting = {0.05, 0.05, 0.07}
room.mdl_origin = Vector(0, 0, 92)

DREAMS.SpawnPoints = room.marks.spawnpoint
DREAMS.Targets = room.marks.info_target
DREAMS.Church = room.marks.church
DREAMS.Loiter = room.marks.church_loiter
DREAMS.Trigger = room.triggers.church_trigger.phys

if CLIENT then
	function DREAMS:SetupFog()
		render.FogMode(MATERIAL_FOG_LINEAR)
		render.FogColor(72, 72, 78)
		render.FogStart(800)
		render.FogEnd(1200)
		render.FogMaxDensity(0.90)
		return true
	end

	local pd_skybox, gritmat
	function DREAMS:Draw(ply, rt)
		Dreams.Meta.Draw(self, ply, rt)
		if not IsValid(pd_skybox) then
			pd_skybox = ClientsideModelSafe("models/dreams/scp1499/skybox.mdl")
			pd_skybox:SetNoDraw(true)
			pd_skybox:SetModelScale(-3)
			pd_skybox:SetAngles(Angle(180, 0, 0))
		end

		pd_skybox:SetRenderMode(RENDERMODE_WORLDGLOW)
		pd_skybox:SetColor(Color(255, 0, 0))
		render.SuppressEngineLighting(true)
		render.ResetModelLighting(0.8, 0.8, 0.8)
		render.OverrideDepthEnable(true, false)
		pd_skybox:SetPos(ply:GetDreamPos() + Vector(0, 0, 64))
		pd_skybox:DrawModel()
		render.OverrideDepthEnable(false)

		if not gritmat or not self.FixedMats then
			gritmat = CreateMaterial("1499gritmat5", "VertexLitGeneric", {
				["$basetexture"] = "rp_scpfoundation_v8/grit2",
				["$model"] = 1,
				--["$translucent"] = 1,
				--["$vertexalpha"] = 1,
				--["$vertexcolor"] = 1
			})
		end


		local redraw
		for k, v in ipairs(self.ListRooms[1].props) do
			if IsValid(v.CMDL) then
				redraw = redraw or v.CMDL:GetMaterial() ~= "!1499gritmat5"
				if not redraw then break end
				v.CMDL:SetMaterial("!1499gritmat5")
			end
		end
		if redraw then Dreams.Meta.Draw(self, ply) end

		render.ResetModelLighting(0.5, 0.5, 0.9)
		self:UpdateNPCS(ply)
		render.SuppressEngineLighting(false)

		-- if not ply.DreamRoom then return end
		-- local hit, wd = Dreams.Lib.TraceRayPhys(ply.DreamRoom.phys, ply:GetDreamPos() + Vector(0, 0, 64), ply:EyeAngles():Forward(), 100)
		-- if hit then
		-- 	//wprint(hit, wd)
		-- 	render.DrawLine(ply:GetDreamPos() + Vector(50, 0, 32), ply:GetDreamPos() + Vector(0, 0, 64) + ply:EyeAngles():Forward() * 300, Color(255, 0, 0), false)
		-- 	render.DrawWireframeSphere(hit, 3, 3, 3, Color(255, 0, 0), false)
		-- end
	end
	local overlay = Material("scp1499/gasoverlay.vmt")
	function DREAMS:DrawHUD(ply, w, h)
		surface.SetMaterial(overlay)
		surface.SetDrawColor(26, 26, 26, 200)
		surface.DrawTexturedRect(0, -30, w, h + 60)
		if self.FadeTime and self.FadeTime > CurTime() then
			surface.SetDrawColor(0, 0, 0, 255 * (self.FadeTime - CurTime()) / 2)
			surface.DrawRect(-1, -1, w + 2, h + 2)

			surface.SetFont("HudSelectionText")
			surface.SetTextColor(255, 255, 255, 255 * (self.FadeTime - CurTime()) / 2)
			surface.SetTextPos(w / 2 - surface.GetTextSize("You put on the gas mask.") / 2, h - 100)
			surface.DrawText("You put on the gas mask.")
		end
		Dreams.Meta.DrawHUD(self, ply)
	end

	local bob = 0
	local bd = false

	local height = Vector(0, 0, 64)
	function DREAMS:CalcView(ply, view)
		local ang = ply:EyeAngles()
		local cos = math_cos(bob)
		local cos2 = math_cos(bob + 0.5)
		ang:RotateAroundAxis(ang:Right(), 0.2 + cos2 * 0.8)
		ang:RotateAroundAxis(ang:Forward(), cos * 1)
		local vel = ply:GetVelocity()
		if math_abs(vel.z) < 1 then
			bob = (bob + Vector(vel.x, vel.y, 0):Length() * FrameTime() / 35) % 6
			if bob % 3 < 0.1 and not bd then
				bd = bob + 0.1
				surface.PlaySound("player/footsteps/tile" .. math.random(1, 3) .. ".wav")
			elseif bd and bob > bd then
				bd = false
			end
		else
			bob = bob - bob * 0.2
		end
		self.ViewPunch = Lerp(FrameTime() * 5, self.ViewPunch or 0, 0)
		view.angles = ang + Angle(-self.ViewPunch * 3, 0, 0)
		view.origin = ply:GetDreamPos() + height
	end
end

if SERVER then
	function DREAMS:Start(ply)
		Dreams.Meta.Start(self, ply)
		ply:SetActiveWeapon(ply:GetWeapon("swep_scp1499") or NULL)
		ply:SetDreamPos(table.Random(self.SpawnPoints).pos)
	end

	DREAMS:AddNetReceiver("hit", function(dream, ply)
		ply:TakeDamage(20)
	end)
else
	function DREAMS:Start(ply)
		self:MakeNPCs()
		timer.Simple(0.1, function()
			surface.PlaySound("1499/use.ogg")
			surface.PlaySound("1499/enter.ogg")
		end)
		self.Triggered = false
		self.FadeTime = CurTime() + 2
		timer.Simple(0.2, function()
			ply:EmitSound("1499/music.wav", 75, 100, 0.3)
		end)
	end

	function DREAMS:ClearNPCS()
		for k, v in pairs(self.NPCS or {}) do
			v:Remove()
		end
		self.NPCS = nil
	end

	function DREAMS:MakeNPCs()
		self:ClearNPCS()
		self.NPCS = {}
		self.ChurchNPCs = {}
		local sps = table.Copy(self.Targets)
		local sp, k
		for i = 1, 12 do
			sp, k = table.Random(sps)
			if not sp then return end
			sps[k] = nil

			if sp.pos:DistToSqr(LocalPlayer():GetDreamPos()) < 300 ^ 2 then continue end
			local cs = ClientsideModelSafe("models/cpthazama/scp/1499-1.mdl")
			local dir = Vector(math.random(-30, 30), math.random(-30, 30))
			cs:SetPos(sp.pos + dir + Vector(math.random(-30, 30), math.random(-30, 30)))
			cs:SetNoDraw(true)
			cs:ResetSequenceInfo()
			cs:SetAngles(dir:Angle())
			if math.random(1, 2) == 2 or math.random(1, 2) == 1 then
				cs:ResetSequence("walk")
				cs.Walking = true
			else
				cs:ResetSequence("idle")
			end
			self.NPCS[i] = cs
		end

		for n, v in pairs(self.Church) do
			local cs = ClientsideModelSafe("models/cpthazama/scp/1499-1.mdl")
			cs:SetPos(v.pos)
			cs:SetNoDraw(true)
			cs:ResetSequenceInfo()
			cs:SetAngles(v.angles)
			self.ChurchNPCs[n] = cs
		end
	end

	function DREAMS:End(ply)
		self:ClearNPCS()
		ply:StopSound("1499/music.wav")
		timer.Simple(0.1, function()
			if not ply:Alive() then ply:EmitSound("zombie/claw_strike1.wav", 75, 100, 0.1) return end
			surface.PlaySound("1499/use.ogg")
			surface.PlaySound("1499/exit.ogg")
		end)
	end

	DREAMS:AddNetSender("hit")
	function DREAMS:UpdateNPCS(ply)
		if not self.NPCS or #self.NPCS == 0 then self:MakeNPCs() end
		local ppos = ply:GetDreamPos()

		if not self.Triggered and self.Loiter.pos:DistToSqr(ppos) < 3000 ^ 2 then
			for k, v in ipairs(self.ChurchNPCs) do
				if not IsValid(v) then table.remove(self.ChurchNPCs, k) continue end
				v:DrawModel()
			end
			if ppos:WithinAABox(self.Trigger.AA, self.Trigger.BB) then
				self.LoiterAmt = (self.LoiterAmt or 0) + 0.1 * FrameTime()
				if self.LoiterAmt > 1 then
					self.NPCS = self.ChurchNPCs
					self:Alarm()
					return
				end
			end
		else
			self.LoiterAmt = 0
		end

		local cycle = self.Cycle or 0
		local phys = self.ListRooms[1].phys
		cycle = (cycle + 0.2 * FrameTime()) % 1
		self.Cycle = cycle
		for k, v in ipairs(self.NPCS or {}) do
			if not IsValid(v) then table.remove(self.NPCS, k) continue end
			local vpos = v:GetPos()
			local skip = vpos:DistToSqr(ppos) > 3000 ^ 2
			if not v.DupeCheck or v.DupeCheck < CurTime() then
				v.DupeCheck = CurTime() + 1 + 0.4 * k

				local inview_np = ply:EyeAngles() - (vpos - ppos):Angle()
				inview_np:Normalize()
				local count = 0
				for c, n in ipairs(self.NPCS) do
					if n == v then continue end
					if n:GetPos():DistToSqr(v:GetPos()) < 100 ^ 2 and not (inview_np.y < 100 and inview_np.y > -100) then
						count = count + 1
					end
					if n:GetPos():DistToSqr(v:GetPos()) < 6 ^ 2 or count >= 4 then
						skip = true
						break
					end
				end
			end

			if skip and (not v.LastSkip or v.LastSkip < CurTime()) then
				v.LastSkip = CurTime() + 1 + 0.2 * k
				local pos
				for a, b in ipairs(self.Targets) do
					if b.Timeout and b.Timeout > CurTime() then continue end
					local sp = b.pos
					local dist = sp:DistToSqr(ppos)
					if dist < 1300 ^ 2 or dist > 3000 ^ 2 then continue end
					local inview = ply:GetVelocity():Angle() - (sp - ppos):Angle()
					inview:Normalize()

					if (inview.y > 85 or inview.y < -85) then continue end
					pos = sp
					b.Timeout = CurTime() + 10
					if not self.Triggered and (math.random(1, 2) == 2 or math.random(1, 2) == 1) then
						v:ResetSequenceInfo()
						v:ResetSequence("walk")
						v.Walking = true
					end
					break
				end
				if pos then v:SetPos(pos) end
				continue
			end
			v:DrawModel()
			--render.DrawWireframeSphere(v:GetPos(), 10, 10, 10, Color(255, 0, 0), false)
			if self.Triggered then
				if v:GetSequence() == v:LookupSequence("idle_panic") then
					kcycle = (cycle + 0.2 * FrameTime())
					if kcycle >= 1 then
						v:ResetSequence("run")
					end
					v:SetCycle(cycle)
				elseif v:GetSequence() == v:LookupSequence"run" then
					local lcycle = (cycle + 0.362978234 * k) % 1
					v:SetCycle(lcycle * 2)
					local dir = ppos - vpos
					dir:SetUnpacked(dir.x, dir.y, 0)
					dir:Normalize()

					local hit = Dreams.Lib.IntersectCylPhys(phys, vpos + Vector(0, 0, 3) + dir * 32, 32, 64)
					if hit then
						dir = dir:Angle():Right()
					end
					v:SetPos(dir * math.min(140 + k * 4, 165) * FrameTime() + vpos)
					v:SetAngles(dir:Angle())

					if ppos:DistToSqr(vpos) < 120 ^ 2 and (not v.LastAttack or v.LastAttack < CurTime()) then
						v.Cycle = 0
						v:ResetSequence("attack1")
					end
				elseif v:GetSequence() == v:LookupSequence"attack1" or v:GetSequence() == v:LookupSequence"attack2" then
					v.Cycle = (v.Cycle or 0) + 1 * FrameTime()
					if v.Cycle >= 0.8 and (not v.LastAttack or v.LastAttack < CurTime())   then
						v.LastAttack = CurTime() + 1
						v:ResetSequence("run")
						if ppos:DistToSqr(vpos) < 130 ^ 2 then
							self:SendCommand("hit")
							self.ViewPunch = 10
							ply:EmitSound("zombie/claw_strike1.wav", 75, 100, 0.1)
						end
					end
					v:SetCycle(v.Cycle)

					local dir = ppos - vpos
					dir:SetUnpacked(dir.x, dir.y, 0)
					dir:Normalize()
					v:SetPos(dir * 80 * FrameTime() + vpos)
					v:SetAngles(dir:Angle())
				end
			elseif v.Walking then
				v:SetPos(v:GetAngles():Forward() * 18 * FrameTime() + vpos)
				local lcycle = (cycle + 0.362978234 * k) % 1
				v:SetCycle(lcycle)

				local hit = Dreams.Lib.IntersectCylPhys(phys, vpos, 32, 64)
				if hit then
					v.Walking = false
					v:ResetSequence("idle")
				end
			else
				v:SetCycle(cycle * 2)
			end
			if vpos:DistToSqr(ppos) < 230 ^ 2 and not self.Triggered then
				self:Alarm()
				break
			end
		end

		if not self.Triggered and math.random(1, 5000) == 321 then
			LocalPlayer():EmitSound("1499/idle" .. math.random(1, 4) .. ".ogg", 75, 100, 0.1)
		end
	end

	function DREAMS:Alarm()
		if self.Triggered then return end
		self.Cycle = 0
		self.Triggered = true
		for k, v in pairs(self.NPCS) do
			v:ResetSequence("idle_panic")
		end
		LocalPlayer():EmitSound("1499/triggered.ogg", 75, 100, 0.3)
	end
end

function DREAMS:SwitchWeapon(ply, old, new)
	if IsValid(new) and new:GetClass() ~= "swep_scp1499" then return true end
end
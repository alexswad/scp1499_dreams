-- This could use a re-do

if not DREAMS then
	Dreams.LoadDreams()
	return
end

DREAMS.MoveSpeed = 10
DREAMS.ShiftSpeed = 18.5
DREAMS.JumpPower = 200
DREAMS.Gravity = 600

local math_cos = math.cos
local math_abs = math.abs
local IsValid = IsValid
local Vector = Vector
local Dreams = Dreams
local CurTime = CurTime

local room = DREAMS:AddRoom("1499", "models/dreams/scp1499/scp1499.mdl", "data/dreams/scp1499_phys.dat", vector_origin)
room.MdlLighting = {0.5, 0.5, 0.6}
room.Lighting = {0.05, 0.05, 0.07}

DREAMS.SpawnPoints = {}
for k, v in pairs(room.Marks) do
	if k:StartsWith("spawnpoint") then
		table.insert(DREAMS.SpawnPoints, v)
	end
end

if CLIENT then
	function DREAMS:SetupFog()
		render.FogMode(MATERIAL_FOG_LINEAR)
		render.FogColor(51, 51, 51)
		render.FogStart(800)
		render.FogEnd(1200)
		render.FogMaxDensity(0.9)
		return true
	end

	local pd_skybox
	function DREAMS:Draw(ply)
		Dreams.Meta.Draw(self, ply)

		if not IsValid(pd_skybox) then
			pd_skybox = ClientsideModelSafe("models/dreams/skybox.mdl")
			pd_skybox:SetNoDraw(true)
			pd_skybox:SetModelScale(-9)
			pd_skybox:SetMaterial("models/props_wasteland/concretewall064b")
		end

		pd_skybox:SetRenderMode(RENDERMODE_TRANSCOLOR)
		pd_skybox:SetColor(Color(255, 0, 0))
		render.SuppressEngineLighting(true)
		render.ResetModelLighting(0, 0, 0)
		pd_skybox:SetPos(ply:GetDreamPos() + Vector(0, 0, 64))
		pd_skybox:DrawModel()

		render.ResetModelLighting(0.5, 0.5, 0.9)
		self:UpdateNPCS(ply)
		render.SuppressEngineLighting(false)

		-- if not ply.DreamRoom then return end
		-- local hit, wd = Dreams.Lib.TracePhys(ply.DreamRoom.phys, ply:GetDreamPos() + Vector(0, 0, 64), ply:EyeAngles():Forward(), 100)
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
	local function find_closest_node(phys, list, startpos, checkpos, last)
		local npos
		for k, v in pairs(list) do
			if last and last:IsEqualTol(v.pos, 100) then continue end
			if npos and v.pos:DistToSqr(checkpos) > npos:DistToSqr(checkpos) then continue end
			local dir = v.pos - startpos
			dir:SetUnpacked(dir.x, dir.y, 0)
			dir:Normalize()
			if Dreams.Lib.TracePhys(phys, startpos, dir, v.pos:DistToSqr(startpos)) then continue end
			npos = v.pos
		end
		return npos
	end

	function DREAMS:Start(ply)
		self:MakeNPCs()
		RunConsoleCommand("stopsound")
		timer.Simple(0.1, function()
			surface.PlaySound("1499/use.ogg")
			surface.PlaySound("1499/enter.ogg")
		end)
		self.Triggered = false
		self.FadeTime = CurTime() + 2
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
		local sps = table.Copy(self.SpawnPoints)
		local sp, k
		for i = 1, 9 do
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
	end

	function DREAMS:End(ply)
		self:ClearNPCS()
		RunConsoleCommand("stopsound")
		if not ply:Alive() then return end
		timer.Simple(0.1, function()
			surface.PlaySound("1499/use.ogg")
			surface.PlaySound("1499/exit.ogg")
		end)
	end

	DREAMS:AddNetSender("hit")
	function DREAMS:UpdateNPCS(ply)
		local cycle = self.Cycle or 0
		local mroom = self.ListRooms[1]
		cycle = (cycle + 0.2 * FrameTime()) % 1
		self.Cycle = cycle
		for k, v in ipairs(self.NPCS or {}) do
			if not IsValid(v) then table.remove(self.NPCS, k) continue end
			local vpos, ppos = v:GetPos(), ply:GetDreamPos()
			local skip = vpos:DistToSqr(ppos) > 2000 ^ 2
			if not v.DupeCheck or v.DupeCheck < CurTime() then
				v.DupeCheck = CurTime() + 0.7 + 0.1 * k

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
				v.LastSkip = CurTime() + 0.5 + 0.1 * k
				local pos
				for a, b in RandomPairs(self.SpawnPoints) do
					if b.Timeout and b.Timeout > CurTime() then continue end
					local sp = b.pos
					local dist = sp:DistToSqr(ppos)
					if dist < 1200 ^ 2 or dist > 1900 ^ 2 then continue end
					local inview = ply:GetVelocity():Angle() - (sp - ppos):Angle()
					inview:Normalize()

					if (inview.y > 85 or inview.y < -85) then continue end
					pos = sp
					b.Timeout = CurTime() + 3
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
					local pos = v.Target or ppos
					local dir = pos - vpos
					dir:SetUnpacked(dir.x, dir.y, 0)
					dir:Normalize()
					local seeplayer = not Dreams.Lib.TracePhys(mroom.phys, vpos + Vector(0, 0, 32), ppos - vpos, vpos:DistToSqr(ppos) - 2)
					if v.Target and seeplayer then
						v.LastTarget = v.Target
						v.Target = nil
						continue
					end

					if not seeplayer and (Dreams.Lib.TracePhys(mroom.phys, vpos + Vector(0, 0, 32), dir, 100 ^ 2) or v.Target and v.Target:DistToSqr(vpos) < 10 ^ 2) then
						if v.LastSearch and v.LastSearch > CurTime() then continue end
						v.LastSearch = CurTime() + 0.5
						if v.Target then
							v.LastTarget = v.Target
						end
						v.Target = find_closest_node(mroom.phys, mroom.Marks, vpos + Vector(0, 0, 2), ppos, v.LastTarget)
						continue
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

				local hit = Dreams.Lib.TracePhys(self.ListRooms[1].phys, vpos + Vector(0, 0, 32), v:GetAngles():Forward(), 100 ^ 2)
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
	end

	function DREAMS:Alarm()
		if self.Triggered then return end
		self.Cycle = 0
		self.Triggered = true
		for k, v in pairs(self.NPCS) do
			v:ResetSequence("idle_panic")
		end
	end
end

function DREAMS:SwitchWeapon(ply, old, new)
	if IsValid(new) and new:GetClass() ~= "swep_scp1499" then return true end
end
if not DREAMS then
	Dreams.LoadDreams()
	return
end

DREAMS.MoveSpeed = 10
DREAMS.ShiftSpeed = 20
DREAMS.JumpPower = 200
DREAMS.Gravity = 600

local math_cos = math.cos
local math_abs = math.abs
local IsValid = IsValid
local Vector = Vector

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
		render.FogMaxDensity(0.8)
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
		for k, v in ipairs(self.NPCS or {}) do
			if not IsValid(v) then table.remove(self.NPCS, k) continue end
			v:DrawModel()
		end
		render.SuppressEngineLighting(false)

		-- if not ply.DreamRoom then return end
		-- local hit, wd = Dreams.Lib.TracePhys(ply.DreamRoom.phys, ply:GetDreamPos() + Vector(0, 0, 64), ply:EyeAngles():Forward())
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
		view.angles = ang
		view.origin = ply:GetDreamPos() + height
	end
end

if SERVER then
	function DREAMS:Start(ply)
		Dreams.Meta.Start(self, ply)
		ply:SetActiveWeapon(ply:GetWeapon("swep_scp1499") or NULL)
		ply:SetDreamPos(table.Random(self.SpawnPoints).pos)
	end
else
	function DREAMS:Start(ply)
		self:MakeNPCs()
		RunConsoleCommand("stopsound")
		timer.Simple(0.1, function()
			surface.PlaySound("1499/use.ogg")
			surface.PlaySound("1499/enter.ogg")
		end)
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
		PrintTable(sps)
		for i = 1, 40 do
			sp, k = table.Random(sps)
			if not sp then return end
			sps[k] = nil

			if sp.pos:DistToSqr(LocalPlayer():GetDreamPos()) < 300 ^ 2 then continue end
			local cs = ClientsideModelSafe("models/cpthazama/scp/1499-1.mdl")
			local dir = VectorRand(-1, 1)  
			dir:SetUnpacked(dir.x, dir.y, 0)
			cs:SetPos(sp.pos + dir * 10 + Vector(math.random(1, 30), math.random(1, 30)) * 1)
			cs:SetNoDraw(true)
			self.NPCS[i] = cs
		end
	end

	function DREAMS:End()
		self:ClearNPCS()
		RunConsoleCommand("stopsound")
		timer.Simple(0.1, function()
			surface.PlaySound("1499/use.ogg")
			surface.PlaySound("1499/exit.ogg")
		end)
	end

end

function DREAMS:SwitchWeapon(ply, old, new)
	if IsValid(new) and new:GetClass() ~= "swep_scp1499" then return true end
end
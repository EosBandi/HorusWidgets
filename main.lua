--[[
ArduPilot FrSky Passthrough Telemetry Horus LUA Script
written 12.2017 by Lukas85

This is free software, you can do what ever you like with it.

additional Info:
widget zone size 172 x 390
message row height: 15px
]]
function spPoll(apmpass)
	while true do
		local sensorId, frameId, dataId, value = sportTelemetryPop()
		local flmode
		if sensorId == apmpass.APM_SENSOR_ID and frameId == apmpass.APM_FRAME_ID then
			local tempvalue1
			local tempvalue2
			local lastchar
			--Text messages (sent 3x whenever a msg is in queue)
			if dataId == 0x5000 then 
				if apmpass.message == "" then 
					local datenow = getDateTime()
					apmpass.message = string.format("%02d:%02d:%02d ", datenow.hour, datenow.min, datenow.sec)
				end
				if  value ~= apmpass.oldword then
					for i = 3, 0, -1 do
						--get char
						tempvalue1 = bit32.rshift(value, i * 8)
						tempvalue2 = bit32.band(tempvalue1, 0x7F)
						lastchar = tempvalue2
						--add char to message
						apmpass.message = apmpass.message .. string.char(tempvalue2)
						--get severity bit (only needs the last 3 bits of the last message chunk)
						tempvalue2 = bit32.band(tempvalue1, 0x80)
						--add severity bit to severity
						apmpass.messagesev = bit32.lshift(apmpass.messagesev, 1)
						tempvalue2 = bit32.rshift(tempvalue2, 7)
						apmpass.messagesev = bit32.bor(apmpass.messagesev, tempvalue2)
					end
					
					-- store message and severity in table and reset string, increase or reset pointer
					if (lastchar ==0) then
						if apmpass.messagepointer < apmpass.msgqueuelen then 
							apmpass.messagepointer = apmpass.messagepointer + 1
						else
							apmpass.messagepointer = 1
						end
						apmpass.messagesev = bit32.band(apmpass.messagesev, 0x07)
						apmpass.severities[apmpass.messagepointer] = apmpass.messagesev
						apmpass.messages[apmpass.messagepointer] = apmpass.message
						apmpass.message = "" 
						apmpass.messagesev = 0
					end
					apmpass.oldword = value
				end
				
			--AP STATUS (2Hz)
			elseif dataId == 0x5001 then 
				--Flight mode
				apmpass.valueTable["flmode"] = bit32.band(value, 0x1F)

				--Simple & supersimple
				tempvalue1 = bit32.rshift(value, 5)
				apmpass.valueTable["flgsimple"] = bit32.band(tempvalue1,0x03)
				
				--Armed flag
				tempvalue1 = bit32.rshift(value, 8)
				apmpass.valueTable["flgarm"] = bit32.band(tempvalue1,0x01)

				--Battery failsafe flag
				tempvalue1 = bit32.rshift(value, 9)
				apmpass.valueTable["flgbatfs"] = bit32.band(tempvalue1,0x01)

				--EKF failsafe
				tempvalue1 = bit32.rshift(value, 10)
				apmpass.valueTable["flgekffs"] = bit32.band(tempvalue1,0x03)
				
			--GPS STATUS (1Hz)
			elseif  dataId == 0x5002 then 
				--Num sats
				apmpass.valueTable["gpssat"] = bit32.band(value, 0x0F)
				
				--GPS fix (NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D >= 3)
				tempvalue1 = bit32.rshift(value, 4)
				apmpass.valueTable["gpsfix"] = bit32.band(tempvalue1,0x03)

				--GPS Horizontal dilution of precision
				tempvalue1 = bit32.rshift(value, 6)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				tempvalue2 = bit32.rshift(value, 7)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["gpsdilh"] = ((10 ^ tempvalue1) * tempvalue2) / 10

				--GPS Vertical dilution of precision
				tempvalue1 = bit32.rshift(value, 14)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				tempvalue2 = bit32.rshift(value, 15)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["gpsdilv"] = ((10 ^ tempvalue1) * tempvalue2) / 10

				--GPS altitude
				tempvalue1 = bit32.rshift(value, 22)
				tempvalue1 = bit32.band(tempvalue1,0x03)
				tempvalue2 = bit32.rshift(value, 24)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["gpsalt"] = ((10 ^ tempvalue1) * tempvalue2) / 10
				tempvalue1 = bit32.rshift(value, 31)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				if tempvalue1 == 1 then apmpass.valueTable["gpsalt"] = apmpass.valueTable.gpsalt * -1 end

			--Battery (1Hz)
			elseif  dataId == 0x5003 then 
				--Batt voltage
				apmpass.valueTable["batvolt"] = bit32.band(value, 0x1FF) / 10
				
				--Current draw
				tempvalue1 = bit32.rshift(value, 9)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				tempvalue2 = bit32.rshift(value, 10)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["batcurr"] = ((10 ^ tempvalue1) * tempvalue2) / 10

				--Total current draw since start-up
				tempvalue1 = bit32.rshift(value, 17)
				apmpass.valueTable["batcap"] = bit32.band(tempvalue1,0x7FFF)
				
			--Battery2 (1Hz)
			elseif  dataId == 0x5008 then 
				--Batt voltage
				apmpass.valueTable["bat2volt"] = bit32.band(value, 0x1FF) / 10
				
				--Current draw
				tempvalue1 = bit32.rshift(value, 9)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				tempvalue2 = bit32.rshift(value, 10)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["bat2curr"] = ((10 ^ tempvalue1) * tempvalue2) / 10

				--Total current draw since start-up
				tempvalue1 = bit32.rshift(value, 17)
				apmpass.valueTable["bat2cap"] = bit32.band(tempvalue1,0x7FFF)

			--HOME (2Hz)
			elseif  dataId == 0x5004 then 
				--Distance between home loc and copter
				tempvalue1 = bit32.band(value,0x03)
				tempvalue2 = bit32.rshift(value, 2)
				tempvalue2 = bit32.band(tempvalue2,0x3FF)
				apmpass.valueTable["homedist"] = ((10 ^ tempvalue1) * tempvalue2)

				--Angle from front of vehicle to the direction of home
				tempvalue1 = bit32.rshift(value, 12)
				apmpass.valueTable["homedir"] = bit32.band(tempvalue1,0x7F) * 3

				--Altitude between home loc and copter
				tempvalue1 = bit32.rshift(value, 19)
				tempvalue1 = bit32.band(tempvalue1,0x03)
				tempvalue2 = bit32.rshift(value, 21)
				tempvalue2 = bit32.band(tempvalue2,0x3FF)
				apmpass.valueTable["homealt"] = ((10 ^ tempvalue1) * tempvalue2) / 10
				tempvalue1 = bit32.rshift(value, 31)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				if tempvalue1 == 1 then apmpass.valueTable["homealt"] = apmpass.valueTable.homealt * -1 end

			--VELANDYAW (2Hz)
			elseif  dataId == 0x5005 then 
				--Vertical velocity
				tempvalue1 = bit32.band(value,0x01)
				tempvalue2 = bit32.rshift(value, 1)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["velv"] = ((10 ^ tempvalue1) * tempvalue2) / 10
				tempvalue1 = bit32.rshift(value, 8)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				if tempvalue1 == 1 then apmpass.valueTable["velv"] = apmpass.valueTable.velv * -1 end
				
				--Horizontal velocity
				tempvalue1 = bit32.rshift(value, 9)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				tempvalue2 = bit32.rshift(value, 10)
				tempvalue2 = bit32.band(tempvalue2,0x7F)
				apmpass.valueTable["velh"] = ((10 ^ tempvalue1) * tempvalue2) / 10

				--Yaw
				tempvalue1 = bit32.rshift(value, 17)
				apmpass.valueTable["yaw"] = bit32.band(tempvalue1,0x7FF) / 5
			--ATTIANDRNG (Max Hz)
			elseif  dataId == 0x5006 then 
				--Roll
				apmpass.valueTable["attr"] = bit32.band(value,0x7FF) / 5
				--Pitch
				tempvalue1 = bit32.rshift(value, 11)
				apmpass.valueTable["attp"] = bit32.band(tempvalue1,0x3FF) / 5
				--Rangefinder distance
				tempvalue1 = bit32.rshift(value, 21)
				tempvalue1 = bit32.band(tempvalue1,0x01)
				tempvalue2 = bit32.rshift(value, 22)
				tempvalue2 = bit32.band(tempvalue2,0x3FF)
				apmpass.valueTable["attrng"] = ((10 ^ tempvalue1) * tempvalue2) / 100

			--PARAMS
			elseif  dataId == 0x5007 then 
				tempvalue1 = bit32.rshift(value, 24)
				tempvalue2 = bit32.band(value,0xFFFFFF)
				if tempvalue1 == 1 then
					apmpass.valueTable["parammavtype"] = tempvalue2
				elseif tempvalue1 == 2 then
					apmpass.valueTable["parambatfsvolt"] = tempvalue2 / 100
				elseif tempvalue1 == 3 then
					apmpass.valueTable["parambatfscap"] = tempvalue2
				elseif tempvalue1 == 4 then
					apmpass.valueTable["parambatcapconf"] = tempvalue2
				elseif tempvalue1 == 5 then
					apmpass.valueTable["parambat2capconf"] = tempvalue2
				end
	
			end
		else
			break
		end
	end
	return
end

--returns message pointer for "msg", 1 being the newest message, [msgqueuelen] the oldest message
function getMsgPointer(apmpass, msg)
    result = apmpass.messagepointer - msg + 1
    if result < 1 then
        result = result + apmpass.msgqueuelen
     end
    return result
end

function roundNumber(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

function getNumParam(apmpass, paramname)
	if apmpass.valueTable[paramname] ~= nil then
		return apmpass.valueTable[paramname]
	end
	return -1
end

function arrayLength(array)
    Count = 0
    for Index, Value in pairs(array) do
      Count = Count + 1
    end
    return Count
end

function drawMessages (apmpass, x, y, nummessages)
	if (arrayLength(apmpass.messages) < nummessages) then 
		nummessages = arrayLength(apmpass.messages)
	end
	local row = 0
	for i = nummessages, 1, -1 do
		local msgnr = getMsgPointer(apmpass, i)
		local bmpsev
		if (apmpass.messages[msgnr] ~= nil) then
			if (apmpass.severities[msgnr] == 6) then 
				MSGCOLOR = BLACK
				bmpsev = apmpass.bmpinfo
			elseif (apmpass.severities[msgnr] == 5
					or apmpass.severities[msgnr] == 4) then 
					MSGCOLOR = YELLOW
					bmpsev = apmpass.bmpwarn
			elseif (apmpass.severities[msgnr] == 3
					or apmpass.severities[msgnr] == 2
					or apmpass.severities[msgnr] == 1
					or apmpass.severities[msgnr] == 0) then 
					MSGCOLOR = RED
					bmpsev = apmpass.bmperror
			end
			-- normal size = 18px lineheight
			-- SMLSIZE = 12px lineheight	
			lcd.drawBitmap(bmpsev, x, y + (row * 15) + 1)
			lcd.setColor(CUSTOM_COLOR, MSGCOLOR)
			lcd.drawText(x + 16, y + (row * 15), apmpass.messages[msgnr], LEFT + SMLSIZE + CUSTOM_COLOR);
		end
		row = row + 1
	end
end

function drawGPS (apmpass, x, y)
		local gpstext = ""
		local gpsfix = getNumParam(apmpass, "gpsfix")
		local gpspic = apmpass.gpsnofix
		--GPS fix (NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D >= 3)
		if gpsfix == 0 then
			gpstext = "NO GPS"
			gpspic = apmpass.gpsnofix
		elseif gpsfix == 1 then
			gpstext = "NO FIX"
			gpspic = apmpass.gpsnofix
		elseif gpsfix == 2 then
			gpstext = "2D FIX"
			gpspic = apmpass.gps2dfix
		elseif gpsfix >= 3 then
			gpstext = "3D FIX"
			gpspic = apmpass.gps3dfix
		end
		lcd.drawBitmap(gpspic, x, y + 2, 50)
		lcd.drawNumber(x + 22, apmpass.zone.y , tostring(getNumParam(apmpass, "gpssat")), MIDSIZE);
		lcd.drawText(x, y+22, gpstext, LEFT + SMLSIZE);
end

function drawVehStat (apmpass, x, y)
		local statustext = ""
		local status = getNumParam(apmpass, "flgarm")
		local ATTRIBUTE = 0
		--GPS fix (NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D >= 3)
		if status == 0 then
			statustext = "DISARMED"
		elseif status == 1 then
			statustext = "ARMED"
			x = x + 20
			ATTRIBUTE = INVERS + BLINK
		end
		lcd.drawText(x, y, statustext, LEFT + TEXT_COLOR + ATTRIBUTE);
end

function drawFlightMode(apmpass, x, y)
	local flmode = getNumParam(apmpass, "flmode")
	local apmfmodt = {
	"Stabilize",
	"Acro",
	"AltHold",
	"Auto",
	"Guided",
	"Loiter",
	"RTL",
	"Circle",
	"",--8
	"Land",
	"", --10
	"Drift",
	"", --12
	"Sport",
	"Flip",
	"AutoTune",
	"PosHold",
	"Brake",
	"Throw",
	"Avoid\30ADSB",
	"Guided\30NoGPS"}
	lcd.drawText(x, y, tostring(apmfmodt[flmode]), LEFT + TEXT_COLOR);
end

function drawBat(apmpass, x, y)
	local batvolt = getNumParam(apmpass, "batvolt")
	local batcurr = getNumParam(apmpass, "batcurr")
	local batcap = getNumParam(apmpass, "batcap")
	local batpwr = batvolt * batcurr
	
	lcd.drawText(x, y, tostring(roundNumber(batvolt, 1)) .."V", LEFT + TEXT_COLOR);
	lcd.drawText(x, y + 18, tostring(roundNumber(batcurr, 1)) .."A", LEFT + TEXT_COLOR);
	lcd.drawText(x, y + 36, tostring(roundNumber(batpwr)) .."W", LEFT + TEXT_COLOR);
	lcd.drawText(x, y + 54, tostring(roundNumber(batcap / 1000, 2)) .."Ah", LEFT + TEXT_COLOR);
end

function drawAltDist(apmpass, x, y)
	local gpsalt = getNumParam(apmpass, "gpsalt")
	local homealt = getNumParam(apmpass, "homealt")
	local homedist = getNumParam(apmpass, "homedist")
	local strhomedist = ""
	if homedist < 1000 then
		strhomedist = tostring(homedist).."m"
	else
		strhomedist = tostring(roundNumber(homedist / 1000, 2)) .. "km"
	end
	
	lcd.drawText(x, y, tostring(gpsalt) .."msl", LEFT + TEXT_COLOR);
	lcd.drawText(x, y + 18, tostring(homealt) .."mho", LEFT + TEXT_COLOR);
	lcd.drawText(x, y + 36, strhomedist, LEFT + TEXT_COLOR);
end

function drawpage(apmpass, page)
	-- clear Background
	lcd.setColor(CUSTOM_COLOR, WHITE)
	lcd.drawFilledRectangle(apmpass.zone.x, apmpass.zone.y, apmpass.zone.w, apmpass.zone.h , CUSTOM_COLOR)
		if page == 1 then -- draw info display
			drawFlightMode(apmpass, apmpass.zone.x + 1, apmpass.zone.y)
			drawVehStat(apmpass, apmpass.zone.x + 140, apmpass.zone.y)
			drawGPS(apmpass, apmpass.zone.x + 315, apmpass.zone.y)
			drawBat(apmpass, apmpass.zone.x + 1, apmpass.zone.y + 25)
			drawAltDist(apmpass, apmpass.zone.x + 315, apmpass.zone.y + 43)
			lcd.drawText(apmpass.zone.x + 315, apmpass.zone.y + 97, tostring(getNumParam(apmpass, "velh")) .. "Km/h", LEFT + 0);
			drawMessages(apmpass, apmpass.zone.x + 1, apmpass.zone.y + 128, 3)
		elseif page == 2 then -- draw only messages (last 10)
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y, "ArduPilot messages:", LEFT + 0);
			drawMessages(apmpass, apmpass.zone.x + 1, apmpass.zone.y + 23, 10)
		elseif page == 3 then -- draw parameters
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y, "parammavtype: ".. tostring(getNumParam(apmpass, "parammavtype")), LEFT + SMLSIZE);
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y + 12, "parambatfsvolt: ".. tostring(getNumParam(apmpass, "parambatfsvolt") .. "V"), LEFT + SMLSIZE);
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y + 24, "parambatfscap: ".. tostring(getNumParam(apmpass, "parambatfscap")) .. "mAh", LEFT + SMLSIZE);
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y + 36, "parambatcapconf: ".. tostring(getNumParam(apmpass, "parambatcapconf")) .. "mAh", LEFT + SMLSIZE);
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y + 48, "parambat2capconf: ".. tostring(getNumParam(apmpass, "parambat2capconf")) .. "mAh", LEFT + SMLSIZE);
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y + 60, "roll: ".. tostring(getNumParam(apmpass, "attr")) .. "°", LEFT + SMLSIZE);
			lcd.drawText(apmpass.zone.x + 1, apmpass.zone.y + 72, "pitch: ".. tostring(getNumParam(apmpass, "attp")) .. "°", LEFT + SMLSIZE);
		end

		--check if telemetry is available
		local rssi = getRSSI()
		if rssi == 0 then
			lcd.drawText(apmpass.zone.x + 105, apmpass.zone.y + 70, "NO DATA", LEFT + TEXT_COLOR + INVERS + BLINK + DBLSIZE);
		end
		--TODO: failsafe "popup" (battery, ekf)
end

function refresh(apmpass) -- called when visible
	--decide which page to show
	local page = getValue(apmpass.options.source)
	if page == 0 then
		page = 2
	elseif page > 50 then
		page = 3
	elseif page < -50 then
		page = 1
	end
	
	spPoll(apmpass)
	drawpage(apmpass, page)
end


local options = {
	{ "source", SOURCE, 1 }
}

local function create(zone, options) -- called on creation of widget
	local APM_SENSOR_ID = 0x1B
	local APM_FRAME_ID = 0x10
	local valueTable = {}
	local oldword = 0
	local message = ""
	local messagesev = 0
	local messages = {}
	local severities = {}
	local msgqueuelen = 10
	local messagepointer = 1
	local bmpwarn = Bitmap.open("/WIDGETS/APMPass/img/14WARN.png")
	local bmpinfo = Bitmap.open("/WIDGETS/APMPass/img/14INFO.png")
	local bmperror = Bitmap.open("/WIDGETS/APMPass/img/14ERR.png")
	local gpsnofix = Bitmap.open("/WIDGETS/APMPass/img/GPSnofix.png")
	local gps2dfix = Bitmap.open("/WIDGETS/APMPass/img/GPS2d.png")
	local gps3dfix = Bitmap.open("/WIDGETS/APMPass/img/GPS3d.png")
	local gps3ddfix = Bitmap.open("/WIDGETS/APMPass/img/GPS3dd.png")

--[[
	-- testvalues, comment out for normal use
	valueTable = {parammavtype = 0, gpsfix = 2, gpsalt = 800, gpssat = 4, flgarm = 1, flmode = 17, batvolt = 23.1, batcurr=18.22, batcap = 150, homealt = 250, homedist = 1000 }
	messages = {"APM:Copter V3.5.0-rc11 (3a3f6c94)","PX4: 33825946 NuttX: 1a99ba58","Frame: QUAD","Initialising APM","EKF2 IMU0 tilt alignment complete","EKF2 IMU0 initial yaw alignment complete","u-blox 1 HW: 00080000 SW: 2.01 (75331)","GPS 1: detected as u-blox at 115200 baud","BAD COMPASS HEALTH","warning"}
	severities = {6,6,6,6,6,6,6,6,2,4}
	messagepointer = 10
]]

	local apmpass = {
		zone=zone,
		options=options,
		APM_SENSOR_ID = APM_SENSOR_ID,
		APM_FRAME_ID = APM_FRAME_ID,
		valueTable = valueTable,
		oldword = oldword,
		message = message,
		messagesev = messagesev,
		messages = messages,
		severities = severities,
		msgqueuelen = msgqueuelen,
		messagepointer = messagepointer,
		bmpwarn = bmpwarn,
		bmpinfo = bmpinfo,
		bmperror = bmperror,
		gpsnofix = gpsnofix,
		gps2dfix = gps2dfix,
		gps3dfix = gps3dfix
	}
	 return apmpass
end

local function update(apmpass, options) -- called on update of telemetry settings
	apmpass.options = options
end

local function background(apmpass) -- called when invisible
	spPoll(apmpass) --get messages also when in background
end


return { name="apmPassTh2", options=options, create=create, update=update, refresh=refresh, background=background } --needed for opentx
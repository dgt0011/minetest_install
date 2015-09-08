--Minetest
--Copyright (C) 2013 sapier
--
--This program is free software; you can redistribute it and/or modify
--it under the terms of the GNU Lesser General Public License as published by
--the Free Software Foundation; either version 2.1 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Lesser General Public License for more details.
--
--You should have received a copy of the GNU Lesser General Public License along
--with this program; if not, write to the Free Software Foundation, Inc.,
--51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

--------------------------------------------------------------------------------
local function get_formspec(tabview, name, tabdata)
	local retval = ""
	 
	local render_details = dump(core.setting_getbool("public_serverlist"))
	
	retval = retval ..
		"label[-0.1,0;".. fgettext("Connect to someone else's world...") .. "]" ..
		"field[0.25,3.25;2.7,0.5;te_address;;" ..
		core.formspec_escape(core.setting_get("address")) .."]" ..
		"field[3.1,3.25;1.5,0.5;te_port;;" ..
		core.formspec_escape(core.setting_get("remote_port")) .."]" ..
		"label[4.8,2.2;".. fgettext("Name/Password") .. "]" ..
--		"checkbox[8,-0.25;cb_public_serverlist;".. fgettext("Public Serverlist") .. ";" ..
		render_details .. "]"

	retval = retval ..
		"button[9.6,2.5;2,1.5;btn_mp_connect;".. fgettext("Enter") .. "]" ..
		"field[5,3.25;2.5,0.5;te_name;;" ..
		core.formspec_escape(core.setting_get("name")) .."]" ..
		"pwdfield[7.5,3.25;2.5,0.5;te_pwd;]"
		
	if render_details then
		retval = retval .. "tablecolumns[" ..
			"color,span=3;" ..
			"text,align=right;" ..                -- clients
			"text,align=center,padding=0.25;" ..  -- "/"
			"text,align=right,padding=0.25;" ..   -- clients_max
			image_column(fgettext("Creative mode"), "creative") .. ",padding=1;" ..
			image_column(fgettext("Damage enabled"), "damage") .. ",padding=0.25;" ..
			image_column(fgettext("PvP enabled"), "pvp") .. ",padding=0.25;" ..
			"color,span=1;" ..
			"text,padding=1]"                               -- name
	else
		retval = retval .. "tablecolumns[text]"
	end
	retval = retval ..
		"table[-0.05,0.5;4.5,2.0;favourites;"

	if #menudata.favorites > 0 then
		retval = retval .. render_favorite(menudata.favorites[1],render_details)

		for i=2,#menudata.favorites,1 do
			retval = retval .. "," .. render_favorite(menudata.favorites[i],render_details)
		end
	end

	if tabdata.fav_selected ~= nil then
		retval = retval .. ";" .. tabdata.fav_selected .. "]"
	else
		retval = retval .. ";0]"
	end

	-- separator
  	retval = retval ..
 		"box[-0.3,3.75;12.4,0.1;#FFFFFF]"
	-- buttons
	retval = retval ..
	    "label[-0.1,3.8;".. fgettext("Go to my world") .. "]" ..
		"button[1,4.5;10,1.5;btn_start_singleplayer;" .. fgettext("Enter") .. "]" -- ..
--		"button[8.25,4.5;2,1.5;btn_config_sp_world;" .. fgettext("Config mods") .. "]"

	return retval
end

--------------------------------------------------------------------------------
local function main_button_handler(tabview, fields, name, tabdata)

	if fields["btn_start_singleplayer"] then
		gamedata.selected_world	= gamedata.worldindex
		gamedata.singleplayer	= true
		core.start()
		return true
	end

	if fields["favourites"] ~= nil then
		local event = core.explode_textlist_event(fields["favourites"])

		if event.type == "CHG" then
			if event.index <= #menudata.favorites then
				local address = menudata.favorites[event.index].address
				local port = menudata.favorites[event.index].port

				if address ~= nil and
					port ~= nil then
					core.setting_set("address",address)
					core.setting_set("remote_port",port)
				end

				tabdata.fav_selected = event.index
			end
		end
		return true
	end

	if fields["cb_public_serverlist"] ~= nil then
		core.setting_set("public_serverlist", fields["cb_public_serverlist"])

		if core.setting_getbool("public_serverlist") then
			asyncOnlineFavourites()
		else
			menudata.favorites = core.get_favorites("local")
		end
		return true
	end

	if fields["cb_creative"] then
		core.setting_set("creative_mode", fields["cb_creative"])
		return true
	end

	if fields["cb_damage"] then
		core.setting_set("enable_damage", fields["cb_damage"])
		return true
	end

	if fields["cb_fly_mode"] then
		core.setting_set("free_move", fields["cb_fly_mode"])
		return true
	end

	if fields["btn_mp_connect"] ~= nil or
		fields["key_enter"] ~= nil then

		gamedata.playername		= fields["te_name"]
		gamedata.password		= fields["te_pwd"]
		gamedata.address		= fields["te_address"]
		gamedata.port			= fields["te_port"]

		local fav_idx = core.get_textlist_index("favourites")

		if fav_idx ~= nil and fav_idx <= #menudata.favorites and
			menudata.favorites[fav_idx].address == fields["te_address"] and
			menudata.favorites[fav_idx].port    == fields["te_port"] then

			gamedata.servername			= menudata.favorites[fav_idx].name
			gamedata.serverdescription	= menudata.favorites[fav_idx].description

			if not is_server_protocol_compat_or_error(menudata.favorites[fav_idx].proto_min,
					menudata.favorites[fav_idx].proto_max) then
				return true
			end
		else
			gamedata.servername			= ""
			gamedata.serverdescription	= ""
		end

		gamedata.selected_world = 0

		core.setting_set("address",fields["te_address"])
		core.setting_set("remote_port",fields["te_port"])

		core.start()
		return true
	end

	if fields["btn_config_sp_world"] ~= nil then
		local configdialog = create_configure_world_dlg(1)

		if (configdialog ~= nil) then
			configdialog:set_parent(tabview)
			tabview:hide()
			configdialog:show()
		end
		return true
	end
end

--------------------------------------------------------------------------------
local function on_activate(type,old_tab,new_tab)
	if type == "LEAVE" then
		return
	end
	if core.setting_getbool("public_serverlist") then
		asyncOnlineFavourites()
	else
		menudata.favorites = core.get_favorites("local")
	end
end

--------------------------------------------------------------------------------
tab_simple_main = {
	name = "main",
	caption = fgettext("Eidy"),
	cbf_formspec = get_formspec,
	cbf_button_handler = main_button_handler,
	on_change = on_activate
	}

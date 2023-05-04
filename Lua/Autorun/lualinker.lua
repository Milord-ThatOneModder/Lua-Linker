-- TODO add some comments and clean up the code, this is bad for now lol
-- add split up to funcion's file and the file with hooks and shit

local function LinkAdd(target, otherTarget)
    target.AddLinked(otherTarget)
    otherTarget.AddLinked(target)
    otherTarget.DisplaySideBySideWhenLinked = true
    target.DisplaySideBySideWhenLinked = true
end

local function LinkRemove(target, otherTarget)
    target.RemoveLinked(otherTarget)
    otherTarget.RemoveLinked(target)
end

local function FindClosestItem(submarine, position)
    local closest = nil
    for key, value in pairs(submarine and submarine.GetItems(false) or Item.ItemList) do
        if value.Linkable and not value.HasTag("notlualinkable") and not value.HasTag("crate") and not value.HasTag("ammobox") and not value.HasTag("door") and not value.HasTag("smgammo") and not value.HasTag("hmgammo") then
            -- check if placabke or if it does not have holdable component
            local check_if_p_or_nh = false
            local holdable = value.GetComponentString("Holdable")
            if holdable == nil then
                check_if_p_or_nh = true
            else
                if holdable.attachable == true then
                    check_if_p_or_nh = true
                end
            end
            if check_if_p_or_nh == true then
                if Vector2.Distance(position, value.WorldPosition) < 100 then
                    if closest == nil then closest = value end
                    if Vector2.Distance(position, value.WorldPosition) <
                        Vector2.Distance(position, closest.WorldPosition) then
                        -- this should prevent items that are inside invetories be linkable
                        if value.ParentInventory == nil then
                            closest = value
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function FindClientCharacter(character)
    if CLIENT then return nil end
    
    for key, value in pairs(Client.ClientList) do
        if value.Character == character then
            return value
        end
    end
end

local function AddMessage(text, client)
    local message = ChatMessage.Create("Lua Linker", text, ChatMessageType.Default, nil, nil)
    message.Color = Color(60, 100, 255)

    if CLIENT then
        Game.ChatBox.AddMessage(message)
    else
        Game.SendDirectChatMessage(message, client)
    end
end

local links = {}
local currsor_pos = 0

if SERVER and Game.IsMultiplayer then
    Networking.Receive("lualinker.clientsidevalue", function (msg)
        local position = Vector2(msg.ReadSingle(), msg.ReadSingle())
        currsor_pos = position
    end)
end

Hook.Add("luaLinker.onUse", "examples.luaLinker", function(statusEffect, delta, item)
    if CLIENT and Game.IsMultiplayer then 
        -- for better accurancy
        client_currsor_pos = (item.ParentInventory.Owner).CursorWorldPosition
            local msg = Networking.Start("lualinker.clientsidevalue")
            msg.WriteSingle(client_currsor_pos.X)
            msg.WriteSingle(client_currsor_pos.Y)
            Networking.Send(msg)
        return
    end


    -- fallabk if sb is clualess
    if currsor_pos == 0 then
        currsor_pos = item.WorldPosition
    end

    if item.ParentInventory == nil or item.ParentInventory.Owner == nil then return end

    local owner = FindClientCharacter(item.ParentInventory.Owner)

    local target = FindClosestItem(item.Submarine, currsor_pos)

    if target == nil then
        AddMessage("No item found", owner)
        return
    end

    if links[item] == nil then
        links[item] = target
        AddMessage(string.format("Link Start: \"%s\"", target.Name), owner)
        currsor_pos = 0
    else
        local otherTarget = links[item]

        if otherTarget == target then
            AddMessage("The linked items cannot be the same", owner)
            links[item] = nil
            return
        end

        for key, value in pairs(target.linkedTo) do
            if value == otherTarget then
                LinkRemove(target, otherTarget)

                AddMessage(string.format("Removed link from \"%s\" and \"%s\"", target.Name, otherTarget.Name), owner)
				links[item] = nil

                if SERVER then
                    -- lets send a net message to all clients so they remove our link
                    local msg = Networking.Start("lualinker.remove")
                    msg.WriteUInt16(UShort(target.ID))
                    msg.WriteUInt16(UShort(otherTarget.ID))
                    Networking.Send(msg)
                end

                return
            end
        end

        LinkAdd(target, otherTarget)

        local text = string.format("Linked \"%s\" into \"%s\"", otherTarget.Name, target.Name)
        AddMessage(text, owner)

        if SERVER then
            -- lets send a net message to all clients so they add our link
            local msg = Networking.Start("lualinker.add")
            msg.WriteUInt16(UShort(target.ID))
            msg.WriteUInt16(UShort(otherTarget.ID))
            Networking.Send(msg)
        end

        links[item] = nil
        currsor_pos = 0
    end
end)

if CLIENT and Game.IsMultiplayer then
    Networking.Receive("lualinker.add", function (msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())
        local otherTarget = Entity.FindEntityByID(msg.ReadUInt16())
        LinkAdd(target, otherTarget)
    end)

    Networking.Receive("lualinker.remove", function (msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())
        local otherTarget = Entity.FindEntityByID(msg.ReadUInt16())
        LinkRemove(target, otherTarget)
    end)
end
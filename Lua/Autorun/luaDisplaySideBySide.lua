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
        if value.Character == character then return value end
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

local linksDisplaySideBySide = {}

Hook.Add("luaDisplaySideBySide.onUse", "examples.luaDisplaySideBySide",
         function(statusEffect, delta, item)
    if CLIENT and Game.IsMultiplayer then return end -- server side only in multiplayer, client side in singleplayer

    if item.ParentInventory == nil or item.ParentInventory.Owner == nil then
        return
    end

    local owner = FindClientCharacter(item.ParentInventory.Owner)

    local target = FindClosestItem(item.Submarine, (item.ParentInventory.Owner).CursorWorldPosition)

    if target == nil then
        AddMessage("No item found", owner)
        return
    end

    if linksDisplaySideBySide[item] == nil then
        linksDisplaySideBySide[item] = target
        -- AddMessage(string.format("Link Start: \"%s\"", target.Name), owner)

        if target.DisplaySideBySideWhenLinked == true then

            target.DisplaySideBySideWhenLinked = false
            AddMessage(string.format(
                           "Removed DisplaySideBySideWhenLinked from \"%s\"",
                           target.Name), owner)

            if SERVER then
                -- lets send a net message to all clients so they remove our DisplaySideBySideWhenLinked
                local msg = Networking.Start("luaDisplaySideBySide.remove")
                msg.WriteUInt16(UShort(target.ID))
                Networking.Send(msg)
            end

            linksDisplaySideBySide[item] = nil
            return
        else

            -- target.AddLinked(otherTarget)
            -- otherTarget.AddLinked(target)
            -- otherTarget.DisplaySideBySideWhenLinked = true

            target.DisplaySideBySideWhenLinked = true
            AddMessage(string.format(
                           "Added DisplaySideBySideWhenLinked to \"%s\"",
                           target.Name), owner)

            if SERVER then
                -- lets send a net message to all clients so they add our DisplaySideBySideWhenLinked
                local msg = Networking.Start("luaDisplaySideBySide.add")
                msg.WriteUInt16(UShort(target.ID))
                Networking.Send(msg)
            end

            linksDisplaySideBySide[item] = nil
            return
        end
    end
end)

if CLIENT and Game.IsMultiplayer then
    Networking.Receive("luaDisplaySideBySide.add", function(msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())

        target.DisplaySideBySideWhenLinked = true
    end)

    Networking.Receive("luaDisplaySideBySide.remove", function(msg)
        local target = Entity.FindEntityByID(msg.ReadUInt16())

        target.DisplaySideBySideWhenLinked = false
    end)
end

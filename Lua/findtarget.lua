local findtarget = {}

-- findowner
findtarget.FindClientCharacter = function (character)
    if CLIENT then return nil end
    
    for key, value in pairs(Client.ClientList) do
        if value.Character == character then
            return value
        end
    end
end

findtarget.currsor_pos = 0

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

findtarget.findtarget = function (item)
    -- TODO TERRIBLIE BAD STUPID SHITTY but seems i cant make it better
    if CLIENT and Game.IsMultiplayer then 
        -- for better accurancy
        local client_currsor_pos = (item.ParentInventory.Owner).CursorWorldPosition
        local msg = Networking.Start("lualinker.clientsidevalue")
        msg.WriteSingle(client_currsor_pos.X)
        msg.WriteSingle(client_currsor_pos.Y)
        Networking.Send(msg)
        return
    end
    Networking.Receive("lualinker.clientsidevalue", function (msg)
        local position = Vector2(msg.ReadSingle(), msg.ReadSingle())
        findtarget.currsor_pos = position
    end)

    -- fallback if sb is clualess
    if findtarget.currsor_pos == 0 then
        findtarget.currsor_pos = item.WorldPosition
    end

    if item.ParentInventory == nil or item.ParentInventory.Owner == nil then return end

    local target = FindClosestItem(item.Submarine, findtarget.currsor_pos)
    return target
end

return findtarget